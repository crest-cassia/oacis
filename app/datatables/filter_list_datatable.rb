class FilterListDatatable

  HEADER  = ['<th>enable</th>', '<th>query</th>', '<th>edit</th>', '<th>delete</th>']

  def initialize(filter_list, count, view, b_exist)
    @b_exist = b_exist
    @view = view
    @count = count
    @filter_list = filter_list
  end

  def as_json(options = {})
    if @b_exist
      {
        draw: @view.params[:draw].to_i,
        recordsTotal: @count,
        recordsFiltered: @count,
        data: data
      }
    else
      {
        draw: @view.params[:draw].to_i,
        recordsTotal: 0,
        recordsFiltered: 0,
        data: data
      }
    end
  end

private

  def data
    a = []
    return a unless @b_exist
    @filter_list.each_with_index do |filter, i|
      tmp = []
      tmp << @view.check_box( :filter_cb, "", {id: "filter_cb_#{i}", class: "filter_enable_cb", checked: filter[:enable]}, true, false )
      tmp << @view.raw( "<p id=\"filter_key_#{i}\" class=\"filter_query\">#{filter[:query]}</p>" )
      tmp << @view.link_to( @view.raw("<i class=\"fa fa-edit\">"), "javascript:void(0);", onclick:"edit_filter(this)")
      tmp <<  @view.link_to( @view.raw("<i class=\"fa fa-trash-o\">"), "javascript:void(0);", onclick:"delete_filter(filter_key_#{i}, #{i})")
      a << tmp
    end
    a
  end

  def filter_lists
    list = []
    @filter_list.each_with_index do |filter, i|
      next if i <= page || i > page+per_page
      list << filter
    end
  end

  def page
    @view.params[:start].to_i
  end

  def per_page
    @view.params[:length].to_i > 0 ? @view.params[:length].to_i : 10
  end

end

