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
end
