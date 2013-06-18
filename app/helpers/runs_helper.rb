module RunsHelper

  def file_path_to_link_path(file_path)
    public_dir = Rails.root.join('public')
    file_path.to_s.sub(/^#{public_dir.to_s}/, '')
  end

  def formatted_elapsed_time(elapsed_time)
    if elapsed_time
      return sprintf("%.2f", elapsed_time)
    else
      return ''
    end
  end

  def status_label(status)
    case status
    when :created
      '<span class="label">created</span>'
    when :running
      '<span class="label label-warning">running</span>'
    when :failed
      '<span class="label label-important">failed</span>'
    when :finished
      '<span class="label label-success">finished</span>'
    else
      "<span class=\"label\">#{status}</span>"
    end
  end
end
