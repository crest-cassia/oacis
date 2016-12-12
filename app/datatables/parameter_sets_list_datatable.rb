class ParameterSetsListDatatable

  def initialize(parameter_sets, parameter_definition_keys, view, num_ps_total, base_ps = nil)
    @view = view
    @param_sets = parameter_sets
    @param_keys = parameter_definition_keys
    @base_ps = base_ps
    @num_ps_total = num_ps_total
  end

  def as_json(options = {})
    {
      draw: @view.params[:draw].to_i,
      recordsTotal: @num_ps_total,
      recordsFiltered: @param_sets.count,
      data: data
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
    parameter_sets_list.map do |param|
      tmp = []
      tmp << @view.content_tag(:i, '', parameter_set_id: param.id.to_s, align: "center", class: "fa fa-search clickable")
      counts = runs_status_counts(param)
      progress = @view.progress_bar( counts.values.inject(:+), counts[:finished], counts[:failed], counts[:running], counts[:submitted] )
      tmp << @view.raw(progress)
      tmp << @view.link_to( @view.shortened_id_monospaced(param.id), @view.parameter_set_path(param) )
      tmp << @view.distance_to_now_in_words(param.updated_at)
      @param_keys.each do |key|
        if @base_ps
          tmp << colorize_param_value(param.v[key], @base_ps.v[key])
        else
          tmp <<  ERB::Util.html_escape(param.v[key])
        end
      end
      if param == @base_ps
        tmp << ''
      else
        if OACIS_READ_ONLY
          tmp << @view.raw('<i class="fa fa-trash-o">')
        else
          tmp << @view.link_to( @view.raw('<i class="fa fa-trash-o">'), param, remote: true, method: :delete, data: {confirm: 'Are you sure?'})
        end
      end
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

  def parameter_sets_list
    @parameter_sets_list ||= fetch_parameter_sets_list
  end

  def runs_status_counts(ps)
    @runs_status_counts_cache ||= ParameterSet.runs_status_count_batch( parameter_sets_list )
    @runs_status_counts_cache[ps.id]
  end

  def fetch_parameter_sets_list
    #"only" is removed due to ParameterSet.runs_status_count can not be called.
    parameter_sets_list = @param_sets.order_by(sort_column_direction)
    parameter_sets_list = parameter_sets_list.skip(page).limit(per_page)
    parameter_sets_list
  end

  def page
    @view.params[:start].to_i
  end

  def per_page
    @view.params[:length].to_i > 0 ? @view.params[:length].to_i : 10
  end

  def sort_column_direction
    a = [sort_columns,sort_directions].transpose
    Hash[*a.flatten]
  end

  def sort_columns
    return ["updated_at"] if @view.params["order"].nil?
    @view.params["order"].keys.sort.map do |key|
      sort_by[@view.params["order"][key]["column"].to_i]
    end
  end

  def sort_directions
    return ["desc"] if @view.params["order"].nil?
    @view.params["order"].keys.sort.map do |key|
      @view.params["order"][key]["dir"] == "desc" ? "desc" : "asc"
    end
  end
end

