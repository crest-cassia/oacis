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
    header = [ "<th style=\"min-width: 18px; width: 1%; padding-left: 5px; padding-right: 5px;\"><input type=\"checkbox\" id=\"ps_check_all\" value=\"true\" #{OACIS_READ_ONLY ? "disabled=\"disabled\"" : ""}/></th>",
               '<th class="span1" style="min-width: 150px;">Progress</th>',
               '<th class="span1" style="min-width: 50px;">ParamSetID</th>',
               '<th class="span1">Updated_at</th>'
             ]
    header += simulator.parameter_definitions.map do |pd|
      '<th class="span1">' + ERB::Util.html_escape(pd.key) + '</th>'
    end
    header
  end

private
  def sort_by
    ["id", "progress", "id", "updated_at"] + @param_keys.map {|key| "v.#{key}"} + ["id"]
  end

  def data
    parameter_sets_list.map do |ps|
      tmp = []
      tmp << @view.check_box_tag("checkbox[ps]", ps.id, false, {align: "center", disabled: OACIS_READ_ONLY})
      counts = runs_status_counts(ps)
      progress = @view.progress_bar( counts.values.inject(:+), counts[:finished], counts[:failed], counts[:running], counts[:submitted] )
      tmp << @view.raw(progress)
      tmp << @view.link_to( @view.shortened_id_monospaced(ps.id), @view.parameter_set_path(ps) )
      tmp << @view.distance_to_now_in_words(ps.updated_at)
      @param_keys.each do |key|
        if @base_ps
          tmp << colorize_param_value(ps.v[key], @base_ps.v[key])
        else
          tmp <<  ERB::Util.html_escape(ps.v[key])
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
    @ps_list_cache ||= get_parameter_set_list
  end

  def get_parameter_set_list
    pss = @param_sets.order_by(sort_column_direction).skip(page).limit(per_page).to_a
    # `to_a` is necessary to fix the contents of parameter_sets_list
    @runs_status_counts_cache = ParameterSet.runs_status_count_batch(pss)

    if sort_columns[0] == "progress"
      pss.sort_by! do |ps|
        r = progress_rate(ps)
      end
      if sort_directions[0] == "desc"
        pss.reverse!
      end
    end
    pss
  end

  def progress_rate(ps)
    counts = runs_status_counts(ps)
    total = counts.inject(0) {|sum, v| sum += v[1]}
    rate = (counts[:finished]*1000000 + counts[:failed]*10000 + counts[:running]*100 + counts[:submitted]*1).to_f / total
    rate
  end

  def runs_status_counts(ps)
    raise "must not happen" if @runs_status_counts_cache.nil?
    @runs_status_counts_cache[ps.id]
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

