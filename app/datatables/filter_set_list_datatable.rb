class FilterSetListDatatable
  include ApplicationHelper

  HEADER = ['<th style="text-align: left;">name</th>']

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
      fl = ParameterSetFilter.where({"filter_set_id": "#{filter_set.id}"})
      b = []
      fl.each_with_index do |f, j|
        b << ParametersUtil.parse_query_hash_to_str(f.query, @simulator)
      end
      filter_list = b
      tmp = []
      trash = OACIS_READ_ONLY ? @view.raw(@view.fa_icon("trash-o"))
        : @view.link_to(@view.raw(@view.fa_icon("trash-o")), @simulator, href: "/simulators/#{@simulator.id}/_delete_filter_set?name=#{filter_set.name}", remote: true, method: :get, data: {confirm: "Delete #{filter_set.name}\nAre you sure?"}, :class => 'delete_link', id: 'delete_filter_set', filter_set_name: "#{filter_set.name}")
      tmp << @view.raw( 
          "<ul class=\"ul-style-none load-fs-margin-delete\">
             <li class=\"load-fs-left\"><a id=\"filter_set_#{i}\" class=\"filter_set_query\" data-dismiss=\"modal\" filter_set_id=\"#{filter_set.id}\" filter_set_name=\"#{filter_set.name}\" simulator_id=\"#{@simulator.id}\" onclick=\"parameter_load_filter_set_ok_click(\'filter_set_#{i}\')\" href=\"javascript:void(0);\">#{filter_set.name}</a></li>
             <li>#{trash}</li>
             <ul class=\"ul-style-none load-fs-margin-delete\">
               <li class=\"load-fs-left\">#{query_badge(filter_list, false)}</li>
             </ul>
           </ul>" )
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

