  function setupRefreshTools(table, lengthDiv) {
    lengthDiv.append(
      '<i class="fa fa-refresh padding-half-em reload_icon clickable" id="list_refresh"></i>' +
      '<div class="auto_reload_setting">' +
      '<label class="form-check-label clickable" for="list_refresh_cb">auto reload<input type="checkbox" class="form-check-input" id="list_refresh_cb" /></label>' +
      '<label for="list_refresh_tb"><input type="text" pattern="^[0-9]*$" class="form-control form-control-sm" id="list_refresh_tb" size="10">sec</label>' +
      '</div>'
    );
    const refresh_icon = lengthDiv.children('#list_refresh');
    refresh_icon.on('click', function() { table.ajax.reload(null, false);});

    setIntervalCommon(table, lengthDiv);
  }

  function setIntervalCommon(objTable, lengthDiv) {
    let interval = sessionStorage.getItem("AUTO_RELOAD_INTERVAL");
    let timer;

    const refresh_cb = lengthDiv.find('#list_refresh_cb');
    const refresh_tb = lengthDiv.find('#list_refresh_tb');

    refresh_tb.val(interval);
    const tmReloadOn = (msec) => {
      timer = setInterval(() => {
        if(refresh_tb.is(':visible')) {
          objTable.ajax.reload(null, false);
        }
      }, msec);
    }
    const tmReloadOff = () => {
      clearInterval(timer);
    }

    refresh_cb.change(function() {
      if(refresh_cb.prop('checked')) {
        sessionStorage.setItem("AUTO_RELOAD_FLG", true);
        if(chkIntervalStr(refresh_tb.val())) {
          interval = refresh_tb.val();
          sessionStorage.setItem("AUTO_RELOAD_INTERVAL", interval);
        }
        else if (chkIntervalStr(sessionStorage.getItem("AUTO_RELOAD_INTERVAL"))) {
          interval = sessionStorage.getItem("AUTO_RELOAD_INTERVAL");
          refresh_tb.val(interval);
        }
        else {
          interval = "5";
          sessionStorage.setItem("AUTO_RELOAD_INTERVAL", "5");
          refresh_tb.val(interval);
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

    refresh_tb.blur(function(){
      if(refresh_cb.prop('checked')) {
        tmReloadOff();
        if(chkIntervalStr(refresh_tb.val())) {
          interval = refresh_tb.val();
          sessionStorage.setItem("AUTO_RELOAD_INTERVAL", interval);
        }
        else {
          interval = sessionStorage.getItem("AUTO_RELOAD_INTERVAL");
          refresh_tb.val(interval)
        }
        const iSec = parseInt(interval);
        const iMsec = iSec * 1000;
        tmReloadOn(iMsec);
      }
    });
   
    if (sessionStorage.getItem("AUTO_RELOAD_FLG") == 'true') {
      refresh_cb.prop("checked", true);
      const iSec = parseInt(interval);
      const iMsec = iSec * 1000;
      tmReloadOn(iMsec);
    }
    else {
      refresh_cb.prop("checked", false);
    }
  }
