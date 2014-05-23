class ParameterSetsListDatatable

  def initialize(parameter_sets, parameter_definition_keys, view, base_ps = nil)
    @view = view
    @param_sets = parameter_sets
    @param_keys = parameter_definition_keys
    @base_ps = base_ps
  end

  def as_json(options = {})
    {
      sEcho: @view.params[:sEcho].to_i,
      iTotalRecords: @param_sets.count,
      iTotalDisplayRecords: parameter_sets_lists.count,
      aaData: data
    }
  end

  def self.header(simulator)
    header = [ '<th style="min-width: 18px; width: 1%"></th>',
               '<th class="span1" style="min-width: 150px;">Progress</th>',
               '<th class="span1" style="min-width: 50px;">ParamSetID</th>',
               '<th class="span1">Updated_at</th>'
             ]
    header += simulator.parameter_definitions.map do |pd|
      '<th class="span1">' + ERB::Util.html_escape(pd.key) + '</th>'
    end
    header << '<th style="min-width: 18px; width: 1%;"></th>'
    header
  end

private
  def sort_by
    ["id", "progress_rate_cache", "id", "updated_at"] + @param_keys.map {|key| "v.#{key}"} + ["id"]
  end

  def data
    parameter_sets_lists.map do |param|
      tmp = []
      tmp << @view.image_tag("/assets/expand.png", parameter_set_id: param.id.to_s, align: "center", state: "close", class: "treebtn")
      counts = param.runs_status_count
      counts.delete(:cancelled)
      progress = @view.progress_bar( counts.values.inject(:+), counts[:finished], counts[:failed], counts[:running] )
      tmp << @view.raw(progress)
      tmp << "<tt>"+@view.link_to( @view.shortened_id(param.id), @view.parameter_set_path(param) )+"</tt>"
      tmp << @view.distance_to_now_in_words(param.updated_at)
      @param_keys.each do |key|
        if @base_ps
          tmp << colorize_param_value(param.v[key], @base_ps.v[key])
        else
          tmp <<  ERB::Util.html_escape(param.v[key])
        end
      end
      tmp << @view.link_to( @view.raw('<i class="icon-trash">'), param, remote: true, method: :delete, data: {confirm: 'Are you sure?'})
      tmp
    end
  end

  def colorize_param_value(val, compared_val)
    escaped = ERB::Util.html_escape(val)
    red = '<font color="red">' + escaped + '</font>'
    blue = '<font color="blue">' + escaped + '</font>'

    if val == compared_val
      escaped
    elsif val == true and compared_val == false
      red
    elsif val == false and compared_val == true
      blue
    elsif val < compared_val
      blue
    elsif val > compared_val
      red
    else
      escaped
    end
  end

  def parameter_sets_lists
    @parameter_sets_lists ||= fetch_parameter_sets_list
  end

  def fetch_parameter_sets_list
    parameter_sets_list = @param_sets.only("v","updated_at").order_by("#{sort_column} #{sort_direction}")
    parameter_sets_list = parameter_sets_list.skip(page).limit(per_page)
    parameter_sets_list
  end

  def page
    @view.params[:iDisplayStart].to_i
  end

  def per_page
    @view.params[:iDisplayLength].to_i > 0 ? @view.params[:iDisplayLength].to_i : 10
  end

  def sort_column
    idx = @view.params[:iSortCol_0].to_i
    sort_by[idx]
  end

  def sort_direction
    @view.params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end

