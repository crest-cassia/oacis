module HostsHelper

  def host_status_label(status)
    case status
    when :submittable
      '<span class="label label-success">submittable</span>'
    when :stopping
      '<span class="label label-important">stopping</span>'
    else
      "<span class=\"label\">#{status}</span>"
    end
  end
end

