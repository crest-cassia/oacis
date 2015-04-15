class RunsListDatatable

  HEADER  = ['<th>RunID</th>', '<th>status</th>', '<th>priority</th>',
             '<th>elapsed</th>',
             '<th>MPI</th>', '<th>OMP</th>', '<th>version</th>',
             '<th>created_at</th>', '<th>finished_at</th>', '<th>host</th>', '<th>job_id</th>',
             '<th style="min-width: 18px; width: 1%;"></th>']
  SORT_BY = ["id", "status", "priority", "real_time",
             "mpi_procs", "omp_threads", "simulator_version",
             "created_at", "finished_at", "submitted_to", "job_id", "id"]

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
      tmp << @view.link_to( @view.shortened_id_monospaced(run.id), @view.run_path(run) )
      tmp << @view.raw( @view.status_label(run.status) )
      tmp << Run::PRIORITY_ORDER[run.priority]
      tmp << @view.formatted_elapsed_time(run.real_time)
      tmp << run.mpi_procs
      tmp << run.omp_threads
      tmp << run.simulator_version
      tmp << @view.distance_to_now_in_words(run.created_at)
      tmp << @view.distance_to_now_in_words(run.finished_at)
      host = run.submitted_to
      tmp << (host ? @view.link_to( host.name, @view.host_path(host) ) : "---")
      tmp << @view.shortened_job_id(run.job_id)
      trash = OACIS_READ_ONLY ? @view.raw('<i class="fa fa-trash-o">')
        : @view.link_to( @view.raw('<i class="fa fa-trash-o">'), run, remote: true, method: :delete, data: {confirm: 'Are you sure?'})
      tmp << trash
      a << tmp
    end
    a
  end

  def runs_lists
    @runs_lists ||= fetch_runs_list
  end

  def fetch_runs_list
    runs_list = @runs.without(:result).order_by(sort_column_direction)
    runs_list = runs_list.skip(page).limit(per_page)
    runs_list
  end

  def page
    @view.params[:iDisplayStart].to_i
  end

  def per_page
    @view.params[:iDisplayLength].to_i > 0 ? @view.params[:iDisplayLength].to_i : 10
  end

  def sort_column_direction
    a = [sort_columns,sort_directions].transpose
    Hash[*a.flatten]
  end

  def sort_columns
    idxs = []
    i=0
    while true
      idx=@view.params[("iSortCol_" + i.to_s).to_sym]
      break unless idx
      idxs << idx.to_i
      i+=1
    end
    idxs.map {|idx| SORT_BY[idx] }
  end

  def sort_directions
    dirs = []
    i=0
    while true
      dir=@view.params[("sSortDir_" + i.to_s).to_sym]
      break unless dir
      dirs << dir == "desc" ? "desc" : "asc"
      i+=1
    end
    dirs
  end
end

