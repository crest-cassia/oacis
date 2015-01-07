class AnalysesListDatatable

  HEADER  = ['<th style="min-width: 18px; width: 1%;"></th>',
             '<th>AnalysisID</th>', '<th>analyzer</th>', '<th>parameters</th>',
             '<th>status</th>',
             '<th>version</th>', '<th>created_at</th>',
             '<th style="min-width: 18px; width: 1%;"></th>']
  SORT_BY = ["id", "id", "analyzer_id", "parameters", "status", "analyzer_version", "updated_at", "id"]

  def initialize(view_context, analyses)
    @view = view_context
    @analyses = analyses
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
      trash = OACIS_READ_ONLY ? @view.raw('<i class="icon-trash">')
        : @view.link_to( @view.raw('<i class="icon-trash">'), arn, remote: true, method: :delete, data: {confirm: 'Are you sure?'})
      [
        @view.image_tag("/assets/expand.png", analysis_id: arn.id.to_s, align: "center", state: "close", class: "treebtn"),
        @view.link_to( @view.shortened_id(arn.id), @view.analysis_path(arn) ),
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
    list = @analyses.order_by("#{sort_column} #{sort_direction}")
    list = list.skip(page).limit(per_page)
    list
  end

  def page
    @view.params[:iDisplayStart].to_i
  end

  def per_page
    @view.params[:iDisplayLength].to_i > 0 ? @view.params[:iDisplayLength].to_i : 10
  end

  def sort_column
    idx = @view.params[:iSortCol_0].to_i
    SORT_BY[idx]
  end

  def sort_direction
    @view.params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

end

