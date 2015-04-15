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
      trash = OACIS_READ_ONLY ? @view.raw('<i class="fa fa-trash-o">')
        : @view.link_to( @view.raw('<i class="fa fa-trash-o">'), arn, remote: true, method: :delete, data: {confirm: 'Are you sure?'})
      [
        @view.image_tag("/assets/expand.png", analysis_id: arn.id.to_s, align: "center", state: "close", class: "treebtn clickable"),
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
    list = @analyses.order_by(sort_column_direction)
    list = list.skip(page).limit(per_page)
    list
  end

  def page
    @view.params[:iDisplayStart].to_i
  end

  def per_page
    @view.params[:iDisplayLength].to_i > 0 ? @view.params[:iDisplayLength].to_i : 10
  end

  def sort_column_direction
    a = [sort_columns,sort_directions].transpose
    Hash[*a.flatten]
  end

  def sort_columns
    idxs = []
    i=0
    while true
      idx=@view.params[("iSortCol_" + i.to_s).to_sym]
      break unless idx
      idxs << idx.to_i
      i+=1
    end
    idxs.map {|idx| SORT_BY[idx] }
  end

  def sort_directions
    dirs = []
    i=0
    while true
      dir=@view.params[("sSortDir_" + i.to_s).to_sym]
      break unless dir
      dirs << dir == "desc" ? "desc" : "asc"
      i+=1
    end
    dirs
  end
end

