module HostsHelper

  def host_status_label(status)
    case status
    when :enabled
      '<span class="label label-success status-label">started</span>'
    when :disabled
      '<span class="label label-default status-label"">suspended</span>'
    else
      "<span class=\"label status-label\" >#{status}</span>"
    end
  end
end

