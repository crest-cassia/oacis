class FilterSetListDatatable

  HEADER = ['<th>select</th>', '<th>name</th>', '<th>delete</th>']

  def initialize(filter_set_list, simulator, view, total_count)
    @view = view
    @simulator = simulator
    @filter_set_list = filter_set_list
    @total_count = total_count
  end

  def as_json(options = {})
    {
      draw: @view.params[:draw].to_i,
      recordsTotal: @total_count,
      recordsFiltered: @total_count,
      data: data
    }
  end

private

  def data
    a = []
    return a if @total_count < 1
    filter_set_lists.each_with_index do |filter_set, i|
      tmp = []
      tmp << @view.radio_button( 'filter_set_rb', '', "#{filter_set.id}", {filter_set_name: "#{filter_set.name}", simulator_id: "#{@simulator.id}"} )
      tmp << @view.raw( "<p id=\"filter_set_#{i}\" class=\"filter_set_query\">#{filter_set.name}</p>" )
      trash = OACIS_READ_ONLY ? @view.raw("<i class=\"fa fa-trash-o\">")
        : @view.link_to( @view.raw("<i class=\"fa fa-trash-o\">"), @simulator, href: "/simulators/#{@simulator.id}/_delete_filter_set?name=#{filter_set.name}", remote: true, method: :get, data: {confirm: "#{filter_set.name}\nAre you sure?"}, :class => 'delete_link', id: 'delete_filter_set', filter_set_name: "#{filter_set.name}")
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

