class AnalysesListDatatable

  HEADER  = ['<th style="min-width: 18px; width: 1%;"></th>',
             '<th>AnalysisID</th>', '<th>analyzer</th>', '<th>parameters</th>',
             '<th>status</th>',
             '<th>version</th>', '<th>created_at</th>',
             '<th style="min-width: 18px; width: 1%;"></th>']
  SORT_BY = ["id", "id", "analyzer_id", "parameters", "status", "analyzer_version", "updated_at", "id"]

  def initialize(analyses, view_context)
    @analyses = analyses
    @view = view_context
  end

  def as_json(options = {})
    {
      draw: @view.params[:draw].to_i,
      recordsTotal: @analyses.count,
      recordsFiltered: analyses_lists.count,
      data: data
    }
  end

private

  def data
    a = analyses_lists.map do |arn|
      analyzer = arn.analyzer
      trash = OACIS_READ_ONLY ? @view.raw('<i class="fa fa-trash-o">')
        : @view.link_to( @view.raw('<i class="fa fa-trash-o">'), arn, remote: true, method: :delete, data: {confirm: 'Are you sure?'})
      [
        @view.content_tag(:i, '', analysis_id: arn.id.to_s, align: "center", class: "fa fa-search clickable"),
        @view.link_to( @view.shortened_id_monospaced(arn.id), @view.analysis_path(arn) ),
        @view.link_to( analyzer.name, @view.analyzer_path(analyzer) ),
        arn.parameters.to_s,
        @view.status_label(arn.status),
        arn.analyzer_version.to_s,
        @view.distance_to_now_in_words(arn.updated_at),
        trash
      ]
    end
    a
  end

  def analyses_lists
    @analyses_lists ||= fetch_analyses_list
  end

  def fetch_analyses_list
    list = @analyses.order_by(sort_column_direction)
    list = list.skip(page).limit(per_page)
    list
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
    @view.params["order"].keys.map do |key|
      SORT_BY[@view.params["order"][key]["column"].to_i]
    end
  end

  def sort_directions
    return ["desc"] if @view.params["order"].nil?
    @view.params["order"].keys.map do |key|
      @view.params["order"][key]["dir"] == "desc" ? "desc" : "asc"
    end
  end
end

