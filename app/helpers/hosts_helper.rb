module HostsHelper

  def host_status_label(status)
    case status
    when :enabled
      '<span class="label label-success" style="width: 70px; display: inline-block;">enabled</span>'
    when :disabled
      '<span class="label label-default" style="width: 70px; display: inline-block;">suspended</span>'
    else
      "<span class=\"label\" style=\"width: 70px; display: inline-block;\">#{status}</span>"
    end
  end
end

