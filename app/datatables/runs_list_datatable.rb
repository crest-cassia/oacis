class RunsListDatatable
  delegate :params, :h, :link_to, :distance_to_now_in_words, :formatted_elapsed_time, :run_path, :raw, :status_label, to: :@view

  def initialize(view)
    @view = view
    @param_sets = ParameterSet.find(@view.params[:id])
    @runs = Run.where(:parameter_set_id => @param_sets.id)
  end

  def as_json(options = {})
    {
      sEcho: @view.params[:sEcho].to_i,
      iTotalRecords: @runs.count,
      iTotalDisplayRecords: runs_lists.count,
      aaData: data
    }
  end

private

  def data
    a = []
    runs_lists.each_with_index do |run,idx|
      tmp = []
      tmp << @view.link_to(idx+1, run_path(run, :anchor => '!tab-about'))
      tmp << raw(status_label(run.status))
      tmp << run.hostname
      tmp << formatted_elapsed_time(run.cpu_time)
      tmp << formatted_elapsed_time(run.real_time)
      tmp << distance_to_now_in_words(run.created_at)
      tmp << distance_to_now_in_words(run.started_at)
      tmp << distance_to_now_in_words(run.finished_at)
      a << tmp
    end
    a
  end

  def runs_lists
    @runs_lists ||= fetch_runs_list
  end

  def fetch_runs_list
    runs_list = @runs.order_by("#{sort_column} #{sort_direction}")
    runs_list = runs_list.skip(page).limit(per_page)
    runs_list
  end

  def page
    @view.params[:iDisplayStart].to_i
  end

  def per_page
    @view.params[:iDisplayLength].to_i > 0 ? @view.params[:iDisplayLength].to_i : 10
  end

  def sort_column
    if @view.params[:iSortCol_0].to_i == 0
      "id"
    else
      "v."+@simulator.parameter_definitions.keys[@view.params[:iSortCol_0].to_i-1]
    end
  end

  def sort_direction
    @view.params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end

