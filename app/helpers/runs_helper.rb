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
      '<span class="label label-default status-label">created</span>'
    when :submitted
      '<span class="label label-info status-label">submitted</span>'
    when :running
      '<span class="label label-warning status-label">running</span>'
    when :failed
      '<span class="label label-danger status-label">failed</span>'
    when :finished
      '<span class="label label-success status-label">finished</span>'
    else
      "<span class=\"label status-label\">#{status}</span>"
    end
  end

  def make_tree_from_result_paths( result_paths, depth = 3 )
    sio = StringIO.new()
    sio.puts '<ul>'
    result_paths.sort.each do |result_path|
      if File.directory?( result_path )
        subpaths = Dir.glob( result_path.join('*') ).map {|x| Pathname.new(x) }
        sio.puts '<li class="folder">' + File.basename(result_path)
        if depth > 1
          sio.puts make_tree_from_result_paths( subpaths, depth - 1 )
        end
        sio.puts '</li>'
      else
        sio.puts "<li><a href=\"#{file_path_to_link_path(result_path)}\">"
        sio.puts File.basename(result_path)
        if result_path.to_s =~ /(\.png|\.jpg|\.bmp)$/i
          sio.puts '<br />'
          sio.puts image_tag( file_path_to_link_path(result_path) )
        elsif result_path.to_s =~ /\.html$/
          sio.puts '<br />'
          sio.puts "<iframe src=#{file_path_to_link_path(result_path)} seamless sandbox=\"allow-same-origin allow-scripts\" onload=\"resizeIframe(this)\"></iframe>"
        end
        sio.puts '</a></li>'
      end
    end
    sio.puts '</ul>'
    sio.string.html_safe
  end
end
