  $.fn.setIntervalCommon = function(id,objTable,objList) {
    let interval = sessionStorage.getItem("AUTO_RELOAD_INTERVAL");
    let timer;
    $("[id="+id+"_list_refresh_tb]").val(interval);
    const tmReloadOn = (msec) => {
      timer = setInterval(() => {
        if (!$('#' + id + "_list_length").is(':visible')) {
          return;
        }
        if(objList.length > 0) {
          for(var i=0; i<objList.length; i++){
            if(objList[i].classList.contains("tab-pane")){
              if (objList[i].classList.contains("active")) {
                objTable.ajax.reload(null, false)
              }
            }else{
              objTable.ajax.reload(null, false)
            }
          }
        }
      }, msec);
    }
    const tmReloadOff = () => {
      clearInterval(timer);
    }

    $("[id="+id+"_list_refresh_cb]").change(function() {
      if($("[id="+id+"_list_refresh_cb]").prop('checked')) {
        sessionStorage.setItem("AUTO_RELOAD_FLG", true);
        if(chkIntervalStr($("[id="+id+"_list_refresh_tb]").val())) {
          interval = $("[id="+id+"_list_refresh_tb]").val();
          sessionStorage.setItem("AUTO_RELOAD_INTERVAL", interval);
        }
        else if (chkIntervalStr(sessionStorage.getItem("AUTO_RELOAD_INTERVAL"))) {
          interval = sessionStorage.getItem("AUTO_RELOAD_INTERVAL");
        }
        else {
          sessionStorage.setItem("AUTO_RELOAD_INTERVAL", "5");
        }
        const iSec = parseInt(interval);
        const iMsec = iSec * 1000;
        tmReloadOn(iMsec);
      }
      else {
        sessionStorage.setItem("AUTO_RELOAD_FLG", false);
        tmReloadOff();
      }
    });

    $("#"+id+"_list_refresh_tb").blur(function(){
      if($("#"+id+"_list_refresh_cb").prop('checked')) {
        tmReloadOff();
        if(chkIntervalStr($("#"+id+"_list_refresh_tb").val())) {
          interval = $("#"+id+"_list_refresh_tb").val();
          sessionStorage.setItem("AUTO_RELOAD_INTERVAL", interval);
        }
        else {
          interval = sessionStorage.getItem("AUTO_RELOAD_INTERVAL");
        }
        const iSec = parseInt(interval);
        const iMsec = iSec * 1000;
        tmReloadOn(iMsec);
      }
    });
   
    $("#"+id+"_list_refresh_cb").on('reload_off',function(){
       tmReloadOff();
    });

    if (sessionStorage.getItem("AUTO_RELOAD_FLG") == 'true') {
      $("[id="+id+"_list_refresh_cb]").prop("checked", true);
      const iSec = parseInt(interval);
      const iMsec = iSec * 1000;
      tmReloadOn(iMsec);
    }
    else {
      $("#"+id+"_list_refresh_tb").prop("checked", false);
    }
  }
