class AnalysesListDatatable

  def initialize(view_context)
    @view = view_context
    @simulator = Simulator.find(@view.params[:id])
    @analyses = @simulator.analyzers_on_parameter_set_group.inject([]) do |sum, azr|
      sum += @simulator.analyses(azr)
    end
  end

  def as_json(options = {})
    {
      sEcho: @view.params[:sEcho].to_i,
      iTotalRecords: @analyses.count,
      iTotalDisplayRecords: analyses_lists.count,
      aaData: data
    }
  end

private

  def data
    a = analyses_lists.map do |arn|
      analyzer = arn.analyzer
      [
        @view.link_to( arn.to_param, @view.analysis_run_path(arn) ),
        @view.distance_to_now_in_words(arn.updated_at),
        @view.status_label(arn.status),
        @view.link_to( analyzer.name, @view.simulator_analyzer_path(analyzer.simulator, analyzer) ),
        analyzer.type,
        arn.analyzable.id
      ]
    end
    a
  end

  def analyses_lists
    @analyses_lists ||= fetch_analyses_list
  end

  def fetch_analyses_list
    list = @analyses.sort_by {|arn| sort_target(arn) }
    list.reverse! if sort_direction == "desc"
    start_idx = per_page * page
    end_idx = [ per_page * (page+1), list.size ].min
    list = list[ start_idx..end_idx ]
    # list = @analyses.order_by("#{sort_column} #{sort_direction}")
    # list = list.skip(page).limit(per_page)
    list
  end

  def page
    @view.params[:iDisplayStart].to_i
  end

  def per_page
    @view.params[:iDisplayLength].to_i > 0 ? @view.params[:iDisplayLength].to_i : 10
  end

  def sort_target(arn)
    case @view.params[:iSortCol_0].to_i
    when 0
      arn.id
    when 1
      arn.updated_at
    when 2
      arn.status
    when 3
      arn.analyzer.name
    when 4
      arn.analyzer.type
    when 5
      arn.analyzable.id
    else
      raise "must not happen"
    end
  end

  def sort_direction
    @view.params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end

