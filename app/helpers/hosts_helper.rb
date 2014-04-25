module HostsHelper

  def host_status_label(status)
    case status
    when :enabled
      '<span class="label label-success">enabled</span>'
    when :disabled
      '<span class="label label-important">disabled</span>'
    else
      "<span class=\"label\">#{status}</span>"
    end
  end
end

