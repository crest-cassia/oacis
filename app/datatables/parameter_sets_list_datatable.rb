class ParameterSetsListDatatable
  delegate :params, :h, :link_to, to: :@view

  def initialize(view)
    @view = view
    @simulator = Simulator.find(params[:id])
    if params[:query_id].present?
      @param_sets = ParameterSetQuery.find(params[:query_id]).parameter_sets
    else
      @param_sets = ParameterSet.where(:simulator_id => @simulator.id)
    end
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: @param_sets.count,
      iTotalDisplayRecords: parameter_sets_lists.count,
      aaData: data
    }
  end

private

  def data
    a = []
    parameter_sets_lists.map do |param|
      tmp = [ link_to(param.id, param) ]
      @simulator.parameter_definitions.each do |key,key_def|
        tmp <<  h(param.v[key])
      end
      a << tmp
    end
    a
  end

  def parameter_sets_lists
    @parameter_sets_lists ||= fetch_parameter_sets_list
  end

  def fetch_parameter_sets_list
    parameter_sets_list = @param_sets.order_by("#{sort_column} #{sort_direction}")
    parameter_sets_list = parameter_sets_list.page(page).limit(per_page)
    parameter_sets_list
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10
  end

  def sort_column
    if params[:iSortCol_0].to_i == 0
      "id"
    else
      "v."+@simulator.parameter_definitions.keys[params[:iSortCol_0].to_i-1]
    end
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end

