class Host
  include DataMapper::Resource
  include Monitoring::Host

  def self.default_repository_name #here we use the hosts_db for the Host objects
   :hosts_db
  end

  property :hostname, String, :key => true
  property :ip, String
  property :ssh_port, Integer
  property :user, String
  property :dist, String
  property :dist_ver, Float
  property :arch, String
  property :pkg_mgr, String
  property :monit_pw, String
  property :monitored, Boolean, :default => false
  property :opt_vars, Object
  has 0..1, :status, :repository => :default
  has n, :hostgroup_members
  has n, :hostgroups, :through => :hostgroup_members

  def initialize(hostname, ip, user, ssh_port, password)
    begin
      #set the parameters as object properties
      self.hostname = hostname
      self.ip = ip
      self.user = user
      self.ssh_port = ssh_port
      #generate random monit password
      o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
      self.monit_pw = (0...8).map { o[rand(o.length)] }.join
      self.opt_vars = {} #initialize opt_vars as an empty hash
      #start connection to remote host
      Net::SSH.start(ip, user, :port => self.ssh_port, :password => password, :timeout => 10) do |ssh|
        distro = ssh.exec!("cat /etc/issue")
        distro = distro.split
        self.dist = distro[0]
        #check OS for package manager and add dist_ver
        if self.dist == "Debian" or self.dist == "Ubuntu"
          self.pkg_mgr = "apt"
          self.dist_ver  = distro[2]
        elsif self.dist == "Fedora" or self.dist == "CentOS"
          self.pkg_mgr = "yum"
          self.dist_ver  = distro[2]
        elsif self.dist == "Arch"
          self.pkg_mgr = "pacman"
          self.dist_ver = 0
        else
          raise #OS not supported yet
        end
        self.arch = ssh.exec!("uname -m").strip #OS architecture
        #upload the ssh key
        ssh.scp.upload!("data/ssh_key.pub", "/tmp/ssh_key.pub")
        ssh.exec "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && cat /tmp/ssh_key.pub >> ~/.ssh/authorized_keys && rm /tmp/ssh_key.pub"
      end
      if !self.save
        raise #couldn't save the object
      end
      mon = Spork.spork do #we fork the monitoring setup for saving time
        self.monitor()
      end
      msg = "Monitoring setup for "+self.hostname+" in progress"
      Notification.create(:type => :info, :message => msg)
      return self #return the object itself
    rescue Net::SSH::AuthenticationFailed
      return false
    rescue Timeout::Error
      return false
    end
  end

  def add_var(name, value)
    vars = self.opt_vars #load opt_vars
    if !vars[name].nil?
      return false #error = varname exists
    end
    vars[name] = value #add a new variable to the hash and update
    self.update(:opt_vars => nil)
    self.update(:opt_vars => vars)
    return true #all ok
  end

  def del_var(name)
    vars = self.opt_vars #load opt_vars
    if vars[name].nil?
      return false #error = varname doesn't exists
    end
    vars.delete(name) #delete the variable and update
    self.update(:opt_vars => nil)
    self.update(:opt_vars => vars)
    return true #all ok
  end

  def delete(revoke)
    if revoke == true
      ssh_key = File.open("data/ssh_key.pub", "r").read.strip
      cmd = '/bin/grep -v "'+ssh_key+'" /root/.ssh/authorized_keys > /tmp/auth_keys && mv /tmp/auth_keys /root/.ssh/authorized_keys'
      exec_cmd(cmd)
    end
    self.hostgroup_members.all.destroy
    if !status.nil?
      self.status.destroy
      self.save
    end
    reload
    return self.destroy
  end
end