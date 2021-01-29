class RunsListDatatable
  SORT_BY = [nil, "id", "status", "priority", "real_time",
             "mpi_procs", "omp_threads", "simulator_version",
             "created_at", "updated_at", "submitted_to", "job_id", "parameter_set_id"]

  def initialize(runs, view)
    @view = view
    @runs = runs
  end

  def as_json(options = {})
    {
      draw: @view.params[:draw].to_i,
      recordsTotal: @runs.count,
      recordsFiltered: @runs.count,
      data: data
    }
  end

  def self.header
    if OACIS_ACCESS_LEVEL == 0
      col0 = '<th style="min-width: 18px; width: 1%; padding-left: 5px; padding-right: 3px;"><input type="checkbox" id="run_check_all" value="true" disabled="disabled" /></th>'
    else
      col0 = '<th style="min-width: 18px; width: 1%; padding-left: 5px; padding-right: 3px;"><input type="checkbox" id="run_check_all" value="true" /></th>'
    end
    header  = [col0,
             '<th class="span1">RunID</th>', '<th class="span1">status</th>',
             '<th class="span1">ParamSetID</th>',
             '<th class="span1">priority</th>',
             '<th class="span1">elapsed</th>',
             '<th class="span1">MPI</th>', '<th class="span1">OMP</th>', '<th class="span1">version</th>',
             '<th class="span1">created_at</th>', '<th class="span1">updated_at</th>', '<th class="span1">host(group)</th>', '<th class="span1">job_id</th>']
    header
  end

private

  def data
    a = []
    runs_lists.each do |run|
      tmp = []
      attr = OACIS_ACCESS_LEVEL==0 ? {align: "center", disabled: "disabled"} : {align: "center"}
      tmp << @view.check_box_tag("checkbox[run]", run.id, false, attr)
      tmp << @view.link_to( @view.shortened_id_monospaced(run.id), @view.run_path(run), data: {toggle: 'tooltip', placement: 'bottom', html: true, 'original-title': _tooltip_title(run)} )
      tmp << @view.raw( @view.status_label(run.status) )
      tmp << @view.link_to(
        @view.shortened_id_monospaced(run.parameter_set.id),
        @view.parameter_set_path(run.parameter_set),
        {
          data: {toggle: 'tooltip', placement: 'bottom', html: true,
                 'original-title': (_parameter_set_tooltip_title(run.parameter_set))
          }
        })
      tmp << Run::PRIORITY_ORDER[run.priority]
      tmp << @view.raw('<span class="run_elapsed">'+@view.formatted_elapsed_time(run.real_time)+'</span>')
      tmp << run.mpi_procs
      tmp << run.omp_threads
      tmp << @view.raw('<span class="run_version">'+run.simulator_version.to_s+'</span>')
      tmp << @view.distance_to_now_in_words(run.created_at)
      tmp << @view.raw('<span class="run_updated_at">'+@view.distance_to_now_in_words(run.updated_at)+'</span>')
      host_like = run.submitted_to || run.host_group
      tmp << (host_like ? @view.link_to( host_like.name, host_like ) : "---")
      tmp << @view.raw('<span class="run_job_id">'+@view.shortened_job_id(run.job_id)+'</span>')
      tmp << "run_list_#{run.id}"
      a << tmp
    end
    a
  end

  def _tooltip_title(run)
    <<EOS
ID  : #{run.id}<br />
seed: #{run.seed}
EOS
  end

  def _parameter_set_tooltip_title(parameter_set)
    parameters = parameter_set.v.inject('') do |str, (k, v)|
      str + "<tr><th>#{k}:</th><td>#{v}</td></tr>"
    end
    html = <<EOS
<table class='table table-condensed'>
  <tbody>
    <tr><th>Simulator</th><td>#{parameter_set.simulator.name}</td></tr>
#{parameters}
  </tbody>
</table>
EOS
    html
  end

  def runs_lists
    @runs.order_by(sort_column_direction).without(:result).skip(page).limit(per_page)
  end

  def page
    @view.params[:start].to_i
  end

  def per_page
    @view.params[:length].to_i > 0 ? @view.params[:length].to_i : 10
  end

  def sort_column_direction
    a = [sort_columns,sort_directions].transpose
    Hash[*a.flatten]
  end

  def sort_columns
    return ["updated_at"] if @view.params["order"].nil?
    @view.params["order"].keys.map do |key|
      SORT_BY[@view.params["order"][key]["column"].to_i]
    end
  end

  def sort_directions
    return ["desc"] if @view.params["order"].nil?
    @view.params["order"].keys.map do |key|
      @view.params["order"][key]["dir"] == "desc" ? "desc" : "asc"
    end
  end
end

