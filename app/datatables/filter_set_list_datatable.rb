class FilterSetListDatatable

  HEADER = ['<th>select</th>', '<th>name</th>', '<th>delete</th>']

  def initialize(filter_set_list, simulator, view)
    @view = view
    @simulator = simulator
    @filter_set_list = filter_set_list
  end

  def as_json(options = {})
    {
      draw: @view.params[:draw].to_i,
      recordsTotal: @filter_set_list.count,
      recordsFiltered: @filter_set_list.count,
      data: data
    }
  end

private

  def data
    a = []
    filter_set_lists.each_with_index do |filter_set, i|
      tmp = []
      tmp << @view.radio_button( 'filter_set_rb', '', "#{filter_set.id}", {filter_set_name: "#{filter_set.name}", simulator_id: "#{@simulator.id}", class: "filter_set_enable_cb"} )
      tmp << @view.raw( "<p id=\"filter_set_#{i}\" class=\"filter_set_query\">#{filter_set.name}</p>" )
      trash = OACIS_READ_ONLY ? @view.raw("<i class=\"fa fa-trash-o\">")
        : @view.link_to( @view.raw("<i class=\"fa fa-trash-o\">"), @simulator, remote: true, method: :delete_filer_set, data: {confirm: "Are you sure?"})
      tmp << trash
      a << tmp
    end
    a
  end

  def filter_set_lists
    @filter_set_list.skip(page).limit(per_page)
  end

  def page
    @view.params[:start].to_i
  end

  def per_page
    @view.params[:length].to_i > 0 ? @view.params[:length].to_i : 10
  end

end

