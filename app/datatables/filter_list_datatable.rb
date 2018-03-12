class FilterListDatatable

  HEADER  = ['<th>enable</th>', '<th>query</th>', '<th>edit</th>', '<th>delete</th>']

  def initialize(filter_list, simulator, view)
    Rails.logger.debug "helper init"
    @view = view
    @simulator = simulator
    @filter_list = filter_list
  end

  def as_json(options = {})
    {
      draw: @view.params[:draw].to_i,
      recordsTotal: @filter_list.count,
      recordsFiltered: @filter_list.count,
      data: data
    }
  end

private

  def data
    Rails.logger.debug "helper data"
    a = []
    filter_lists.each_with_index do |filter, i|
      tmp = []
      tmp << @view.check_box( :filter_cb, id: "filter_cb_#{i}" )
      tmp << @view.raw( "<p id=\"filter_key_#{i}\" class=\"filter_query\">#{query_parser(filter.query)}</p>" )
      edit = OACIS_READ_ONLY ? @view.raw("<i class=\"fa fa-edit\">")
        : @view.link_to( @view.raw("<i class=\"fa fa-edit\">"), "javascript:void(0);", onclick:"edit_filter(#{i})")
      tmp << edit
      trash = OACIS_READ_ONLY ? @view.raw("<i class=\"fa fa-trash-o\">")
        : @view.link_to( @view.raw("<i class=\"fa fa-trash-o\">"), "javascript:void(0);", onclick:"delete_filter(#{i})", data: {confirm: "Are you sure?"})
      tmp << trash
      a << tmp
    end
    a
  end

  def query_parser(query_hash)
    query_str = ""
    query_hash.each do |key, criteria|
      query_str << key
      criteria.each do |k, v|
        query_str << " " << cnv_operator(key, k) << " " << v
      end
    end
    query_str
  end

  def cnv_operator(parameter, operator)
    disp_operator = operator
    pd = @simulator.parameter_definition_for(parameter)
    disp_operator = ParametersUtil.get_ohperater_string(parameter, operator, pd)
  end

  def filter_lists
    @filter_list.skip(page).limit(per_page)
  end

  def page
    @view.params[:start].to_i
  end

  def per_page
    @view.params[:length].to_i > 0 ? @view.params[:length].to_i : 10
  end

end

