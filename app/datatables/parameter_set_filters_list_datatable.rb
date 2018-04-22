class ParameterSetFiltersListDatatable
  include ApplicationHelper

  HEADER = ['<th style="text-align: left;">name</th>']

  def initialize(filters, simulator, view, total_count)
    @view = view
    @simulator = simulator
    @filters = filters
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
    @filters.each_with_index do |filter, i|
      tmp = []
      trash = OACIS_READ_ONLY ? @view.raw(@view.fa_icon("trash-o")) # [TODO] disable link
                  : @view.link_to(@view.raw(@view.fa_icon("trash-o")), '/') #[TODO]: set a correct link
      tmp << @view.raw(
          "<ul>
             <li><a id=\"filter_#{i}\" filter_id=\"#{filter.id}\">#{filter.name}</a></li>
             <li>#{trash}</li>
             <ul>
               <li style=\"text-align: left\">#{query_badge(filter)}</li>
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

