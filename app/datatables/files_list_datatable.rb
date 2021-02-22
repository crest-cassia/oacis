class FilesListDatatable
  def initialize(runs, view)
    @view = view
    @runs = runs
  end

  def as_json(options = {})
    {
      draw: @view.params[:draw].to_i,
      recordsTotal: @runs.count,
      recordsFiltered: @runs.count,
      data: data
    }
  end

  def self.header
    [ '<th class="span1">RunID</th>', '<th class="span1">Detail</th>' ]
  end

private

  def data
    return [] if file_name.blank?

    @runs.order(updated_at: :desc).skip(page).limit(per_page).map do |run|
      arr = []
      arr << @view.link_to(@view.shortened_id_monospaced(run.id), @view.run_path(run), data: { toggle: 'tooltip', placement: 'bottom', html: true, 'original-title': _tooltip_title(run) })
      path = run.result_paths.select {|result_path| result_path.fnmatch?("*/#{file_name}") }.first.to_s
      public_path = path.sub(/^#{Rails.root.join('public')}/, '')
      case file_name
      when /(\.png|\.jpg|\.bmp)$/i
        detail = @view.link_to(@view.image_tag(public_path, class: 'img-thumbnail'), public_path)
        arr << "<div class=\"pull-right\" style=\"width: 300px\">#{detail}</div>"
      when /^_output\.json$/
        output_json = JSON.parse(File.read(path))
        detail = @view.render_output_json(output_json)
        arr << "<div class=\"pull-right\" style=\"width: 500px;\">#{detail}</div>"
      else
        detail = @view.link_to('[Show]', public_path)
        arr << "<div class=\"pull-right\" style=\"width: 300px\">#{detail}</div>"
      end
    end
  end

  def page
    @view.params[:start].to_i
  end

  def per_page
    @view.params[:length].to_i > 0 ? @view.params[:length].to_i : 10
  end

  def file_name
    @view.params[:file_name]
  end

  def _tooltip_title(run)
    <<EOS
ID  : #{run.id}<br />
seed: #{run.seed}
EOS
  end
end
