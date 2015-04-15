class AnalyzersListDatatable

  SORT_BY = ["id", "id", "name", "type", "description", "id"]

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
      trash = OACIS_READ_ONLY ? @view.raw('<i class="fa fa-trash-o">') : @view.link_to(@view.raw('<i class="fa fa-trash-o">'), azr, remote: true, method: :delete, data: {confirm: 'Are you sure? Dependent analyses are also going to be destroyed.'})
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
    list = @analyzers.order_by(sort_column_direction)
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

