class AnalyzersListDatatable

  def initialize(view_context)
    @view = view_context
    @simulator = Simulator.find(@view.params[:id])
    @analyzers = @simulator.analyzers
  end

  def as_json(options = {})
    {
      sEcho: @view.params[:sEcho].to_i,
      iTotalRecords: @analyzers.count,
      iTotalDisplayRecords: @analyzers.count,
      aaData: data
    }
  end

  def self.header(simulator)
    header = [ '<th style="min-width: 18px; width: 1%"></th>',
               '<th class="span1">AnalyzerID</th>',
               '<th class="span1">Name</th>',
               '<th class="span1">Type</th>',
               '<th class="span1">Description</th>',
               '<th style="min-width: 18px; width: 1%;"></th>'
             ]
    header
  end

private

  def data
    a = analyzers_lists.map do |azr|
      trash = OACIS_READ_ONLY ? @view.raw('<i class="icon-trash">') : @view.link_to(@view.raw('<i class="icon-trash">'), azr, remote: true, method: :delete, data: {confirm: 'Are you sure? Dependent analyses are also going to be destroyed.'})
      [
        @view.image_tag("/assets/expand.png", analyzer_id: azr.id.to_s, align: "center", state: "close", class: "treebtn"),
        @view.link_to( @view.shortened_id(azr.id), @view.analyzer_path(azr) ),
        azr.name,
        azr.type,
        azr.description,
        trash
      ]
    end
    a
  end

  def analyzers_lists
    @analyzers_lists ||= fetch_analyzers_list
  end

  def fetch_analyzers_list
    list = @analyzers.order_by("#{sort_column} #{sort_direction}")
    list = list.skip(page).limit(per_page)
    list
  end

  def page
    @view.params[:iDisplayStart].to_i
  end

  def per_page
    @view.params[:iDisplayLength].to_i > 0 ? @view.params[:iDisplayLength].to_i : 10
  end

  COLUMN_KEYS = ["id", "id", "name", "tyoe", "description", "id"]
  def sort_column
    idx = @view.params[:iSortCol_0].to_i
    COLUMN_KEYS[idx]
  end

  def sort_direction
    @view.params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end

end

