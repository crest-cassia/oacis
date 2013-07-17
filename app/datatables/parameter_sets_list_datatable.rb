class ParameterSetsListDatatable

  def initialize(parameter_sets, parameter_definition_keys, view)
    @view = view
    @param_sets = parameter_sets
    @param_keys = parameter_definition_keys
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
               '<th class="span1" style="min-width: 50px;">ID</th>',
               '<th class="span1">Updated_at</th>'
             ]
    simulator.parameter_definitions.keys.each do |key|
      header << '<th class="span1">' + ERB::Util.html_escape(key) + '</th>'
    end
    header
  end

private
  def sort_by
    ["id", "id", "id", "updated_at"] + @param_keys.map {|key| "v.#{key}"}
  end

  def data
    a = []
    parameter_sets_lists.map do |param|
      tmp = []
      tmp << @view.image_tag("/assets/expand.png", parameter_set_id: param.id.to_s, align: "center", state: "close", class: "treebtn")
      count = param.runs_status_count
      progress = @view.progress_bar( count[:total], count[:finished], count[:running], count[:failed] )
      tmp << @view.raw(progress)
      tmp << "<tt>"+@view.link_to( @view.shortened_id(param.id), @view.parameter_set_path(param) )+"</tt>"
      tmp << @view.distance_to_now_in_words(param.updated_at)
      @param_keys.each do |key|
        tmp <<  ERB::Util.html_escape(param.v[key])
      end
      a << tmp
    end
    a
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

