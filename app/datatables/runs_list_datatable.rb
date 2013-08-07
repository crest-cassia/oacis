class RunsListDatatable

  HEADER  = ['<th>ID</th>', '<th>status</th>', '<th>submitted_to</th>', '<th>cpu_time</th>',
             '<th>real_time</th>', '<th>MPI</th>', '<th>OMP</th>',
             '<th>created_at</th>', '<th>submitted_at</th>',
             '<th>started_at</th>', '<th>finished_at</th>', '<th style="min-width: 18px; width: 1%;"></th>']
  SORT_BY = ["id", "status", "submitted_to", "cpu_time",
             "real_time", "created_at", "submitted_at",
             "started_at", "finished_at", "id"]

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
    runs_lists.each do |run|
      tmp = []
      tmp << @view.link_to( @view.shortened_id(run.id), @view.run_path(run) )
      tmp << @view.raw( @view.status_label(run.status) )
      host = run.submitted_to
      tmp << (host ? @view.link_to( host.name, @view.host_path(host) ) : "")
      tmp << @view.formatted_elapsed_time(run.cpu_time)
      tmp << @view.formatted_elapsed_time(run.real_time)
      tmp << run.mpi_procs
      tmp << run.omp_threads
      tmp << @view.distance_to_now_in_words(run.created_at)
      tmp << @view.distance_to_now_in_words(run.submitted_at)
      tmp << @view.distance_to_now_in_words(run.started_at)
      tmp << @view.distance_to_now_in_words(run.finished_at)
      tmp << @view.link_to( @view.raw('<i class="icon-trash">'), run, remote: true, method: :delete, data: {confirm: 'Are you sure?'})
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

