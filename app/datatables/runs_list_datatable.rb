class RunsListDatatable
  delegate :params, :h, :link_to, :distance_to_now_in_words, :formatted_elapsed_time, :run_path, :raw, :status_label, to: :@view

  HEADER  = ['#', 'status', 'submitted_to', 'cpu_time', 'real_time',
             'created_at', 'submitted_at', 'started_at', 'finished_at']
  SORT_BY = ["id", "status", "submitted_to", "cpu_time", "real_time",
             "created_at", "submitted_at", "started_at", "finished_at"]

  def initialize(runs, view)
    @view = view
    @runs = runs
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
      tmp << @view.link_to(idx+1, run_path(run))
      tmp << raw(status_label(run.status))
      host = run.submitted_to
      tmp << (host ? @view.link_to( host.name, @view.host_path(host) ) : "")
      tmp << formatted_elapsed_time(run.cpu_time)
      tmp << formatted_elapsed_time(run.real_time)
      tmp << distance_to_now_in_words(run.created_at)
      tmp << distance_to_now_in_words(run.submitted_at)
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
    idx = @view.params[:iSortCol_0].to_i
    SORT_BY[idx]
  end

  def sort_direction
    @view.params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end

