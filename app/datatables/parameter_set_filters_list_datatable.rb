class ParameterSetFiltersListDatatable
  include ApplicationHelper

  HEADER = ['<th style="text-align: left;"></th>']

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
      delete_url = Rails.application.routes.url_helpers._delete_filter_simulator_path(@simulator)
      trash = (OACIS_ACCESS_LEVEL >= 1) ?
                  "<a href='#' data-delete-url='#{delete_url}' data-filter-id='#{filter.id}'>#{@view.raw(@view.fa_icon('trash-o'))}</a>" :
                  @view.raw(@view.fa_icon('trash-o'))
      edit = (OACIS_ACCESS_LEVEL >= 1) ?
                  "<a href='#' data-filter-id='#{filter.id}' data-filter-name='#{filter.name}' data-filter-conditions='#{filter.conditions}' id='edit_filter_btn'>#{@view.raw(@view.fa_icon('edit'))}</a>" :
                  @view.raw(@view.fa_icon('edit'))
      tmp << @view.raw(
          "<ul style=\"list-style: none; margin: 0px; padding: 0px;\">
             <li style=\"float: left;\"><a href=\"#{filter_path(filter)}\">#{filter.name}</a></li>
             <li>#{edit} #{trash}</li>
             <ul style=\"list-style: none; margin: 0px; padding: 0px;\">
               <li style=\"text-align: left; margin-top: 5px;\">#{query_badge(filter)}</li>
             </ul>
           </ul>" )
      a << tmp
    end
    a
  end

  def filter_path(f)
    Rails.application.routes.url_helpers.simulator_path(f.simulator, filter: f.id)
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

