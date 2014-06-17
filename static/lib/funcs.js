$(function() {
  $("#add").click(function() {
    $("#add_form").toggle(); $("#add").remove();
  });

  $(".import_key").click(function() {
    $("#import").toggle();
  });

  $(".import_key").click(function() {
    $("#gen").toggle();
  });

  $('.srv').width(
    Math.max.apply(
      Math,
      $('.srv').map(function(){
        return $(this).outerWidth();
      }).get()
    )
  );

  $("input,select,textarea").not("[type=submit]").jqBootstrapValidation();

  $('div.btn-group[data-toggle-name=*]').each(function(){
    var group   = $(this);
    var form    = group.parents('form').eq(0);
    var name    = group.attr('data-toggle-name');
    var hidden  = $('input[name="' + name + '"]', form);
    $('button', group).each(function(){
      var button = $(this);
      button.live('click', function(){
          hidden.val($(this).val());
      });
      if(button.val() == hidden.val()) {
        button.addClass('active');
      }
    });
  });
});

function passDataToModal(data, modal_id) {
  $(".modal-body #dataInput").text(data);
  $(".modal-footer #dataInput").val( data );
  $(modal_id).modal('show');
}

function dismissNotification(msg_id)
{
  var xmlhttp;
  if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
    xmlhttp=new XMLHttpRequest();
  }
  else
  {// code for IE6, IE5
    xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }
  xmlhttp.open("POST","/notifications/dismiss",true);
  xmlhttp.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
  xmlhttp.send("msg_id=" + msg_id);
}
