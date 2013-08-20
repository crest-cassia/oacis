class AnalysesListDatatable

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
      [
        @view.image_tag("/assets/expand.png", analysis_id: arn.id.to_s, align: "center", state: "close"),
        @view.link_to( @view.shortened_id(arn.id), @view.analysis_path(arn) ),
        @view.distance_to_now_in_words(arn.updated_at),
        @view.status_label(arn.status),
        @view.link_to( analyzer.name, @view.analyzer_path(analyzer) ),
        arn.analyzable.id
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

  COLUMN_KEYS = ["id", "id", "updated_at", "status", "analyzer_id", "analyzable_id"]
  def sort_column
    idx = @view.params[:iSortCol_0].to_i
    COLUMN_KEYS[idx]
  end

  def sort_direction
    @view.params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

end

