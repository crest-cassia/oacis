class FilterListDatatable

  HEADER  = ['<th>enable</th>', '<th>query</th>', '<th>edit</th>', '<th>delete</th>']

  def initialize(filter_list, view)
    @view = view
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
    a = []
    filter_lists.each_with_index do |filter, i|
      tmp = []
      tmp << @view.check_box( :filter_cb, id: "filter_cb_#{i}" )
      tmp << @view.raw( "<p id=\"filter_key_#{i}\" class=\"filter_query\">#{filter.query.to_s}</p>" )
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

