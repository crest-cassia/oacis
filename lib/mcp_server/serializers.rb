module McpServer

  # Plain-hash JSON shapes shared by all tools.
  # All ids are strings, symbols are strings, timestamps are ISO8601.
  module Serializers

    RESULT_JSON_LIMIT = 50_000  # bytes; larger results are elided from tool output

    module_function

    # Translates a server-local directory path into one valid for the MCP client,
    # using OACIS_MCP_DIR_MAP="server_prefix=client_prefix" (e.g. set by
    # oacis_docker's oacis_mcp.sh so an agent on the Docker host receives host
    # paths for the mounted Result directory). No-op when the variable is unset
    # or the path is outside the mapped prefix.
    def map_dir(path)
      s = path.to_s
      mapping = ENV['OACIS_MCP_DIR_MAP'].to_s
      return s if mapping.empty?
      from, to = mapping.split('=', 2)
      return s if from.nil? || to.nil? || from.empty?
      from = from.chomp(File::SEPARATOR)
      if s == from || s.start_with?(from + File::SEPARATOR)
        to.chomp(File::SEPARATOR) + s[from.size..-1]
      else
        s
      end
    end

    def simulator(sim, runs_status_count: nil)
      {
        "id" => sim.id.to_s,
        "name" => sim.name,
        "description" => sim.description,
        "command" => sim.command,
        "support_mpi" => sim.support_mpi,
        "support_omp" => sim.support_omp,
        "parameter_definitions" => sim.parameter_definitions.map {|pd| parameter_definition(pd) },
        "executable_on" => sim.executable_on.map(&:name),
        "analyzers" => sim.analyzers.map {|azr| analyzer(azr) },
        "parameter_sets_count" => sim.parameter_sets.count,
        "runs_status_count" => clean(runs_status_count || sim.runs_status_count)
      }
    end

    def parameter_definition(pd)
      h = {
        "key" => pd.key,
        "type" => pd.type,
        "default" => clean(pd.default),
        "description" => pd.description
      }
      h["options"] = pd.options_array if pd.type == "Selection"
      h
    end

    def analyzer(azr)
      {
        "id" => azr.id.to_s,
        "name" => azr.name,
        "type" => azr.type.to_s,  # "on_run" or "on_parameter_set"
        "description" => azr.description,
        "command" => azr.command,
        "auto_run" => azr.auto_run.to_s,
        "files_to_copy" => azr.files_to_copy,
        "support_mpi" => azr.support_mpi,
        "support_omp" => azr.support_omp,
        "parameter_definitions" => azr.parameter_definitions.map {|pd| parameter_definition(pd) },
        "executable_on" => azr.executable_on.map(&:name)
      }
    end

    def host(host)
      {
        "id" => host.id.to_s,
        "name" => host.name,
        "status" => host.status.to_s,
        "max_num_jobs" => host.max_num_jobs,
        "min_mpi_procs" => host.min_mpi_procs,
        "max_mpi_procs" => host.max_mpi_procs,
        "min_omp_threads" => host.min_omp_threads,
        "max_omp_threads" => host.max_omp_threads,
        "host_parameter_definitions" => host.host_parameter_definitions.map do |d|
          { "key" => d.key, "default" => clean(d.default), "format" => d.format, "options" => d.options }
        end,
        "default_host_parameters" => clean(host.default_host_parameters)
      }
    end

    def host_group(hg)
      {
        "id" => hg.id.to_s,
        "name" => hg.name,
        "hosts" => hg.hosts.map(&:name)
      }
    end

    def parameter_set(ps, run_counts: nil)
      h = {
        "id" => ps.id.to_s,
        "simulator" => ps.simulator.name,
        "v" => clean(ps.v),
        "created_at" => time(ps.created_at),
        "updated_at" => time(ps.updated_at)
      }
      h["run_counts"] = clean(run_counts) if run_counts
      h
    end

    def run(run, brief: false)
      h = {
        "id" => run.id.to_s,
        "status" => run.status.to_s,
        "priority" => run.priority,
        "submitted_to" => run.submitted_to&.name,
        "host_group" => run.host_group&.name,
        "created_at" => time(run.created_at),
        "updated_at" => time(run.updated_at)
      }
      h["error_present"] = true if brief && run.error_messages.present?
      return h if brief
      h.merge(
        "parameter_set_id" => run.parameter_set_id.to_s,
        "simulator" => run.simulator&.name,
        "dir" => map_dir(run.dir),
        "host_parameters" => clean(run.host_parameters),
        "mpi_procs" => run.mpi_procs,
        "omp_threads" => run.omp_threads,
        "seed" => run.seed,
        "job_id" => run.job_id,
        "error_messages" => run.error_messages,
        "hostname" => run.hostname,
        "cpu_time" => run.cpu_time,
        "real_time" => run.real_time,
        "started_at" => time(run.started_at),
        "finished_at" => time(run.finished_at),
        "simulator_version" => run.simulator_version,
        "result" => capped_result(run.result)
      )
    end

    def analysis(anl, brief: false)
      h = {
        "id" => anl.id.to_s,
        "analyzer" => anl.analyzer&.name,
        "status" => anl.status.to_s,
        "analyzable_type" => anl.analyzable_type,  # "Run" or "ParameterSet"
        "analyzable_id" => anl.analyzable_id.to_s,
        "parameters" => clean(anl.parameters),
        "created_at" => time(anl.created_at),
        "updated_at" => time(anl.updated_at)
      }
      return h if brief
      h.merge(
        "parameter_set_id" => anl.parameter_set_id.to_s,
        "dir" => map_dir(anl.dir),
        "submitted_to" => anl.submitted_to&.name,
        "host_group" => anl.host_group&.name,
        "host_parameters" => clean(anl.host_parameters),
        "mpi_procs" => anl.mpi_procs,
        "omp_threads" => anl.omp_threads,
        "priority" => anl.priority,
        "job_id" => anl.job_id,
        "error_messages" => anl.error_messages,
        "hostname" => anl.hostname,
        "cpu_time" => anl.cpu_time,
        "real_time" => anl.real_time,
        "started_at" => time(anl.started_at),
        "finished_at" => time(anl.finished_at),
        "analyzer_version" => anl.analyzer_version,
        "result" => capped_result(anl.result)
      )
    end

    def capped_result(result)
      return nil if result.nil?
      cleaned = clean(result)
      json = JSON.generate(cleaned)
      if json.bytesize > RESULT_JSON_LIMIT
        {
          "_truncated" => true,
          "_note" => "result is #{json.bytesize} bytes of JSON (limit #{RESULT_JSON_LIMIT}); read _output.json under 'dir' directly, or use list_result_files / read_result_file.",
          "_keys" => (cleaned.is_a?(Hash) ? cleaned.keys : nil)
        }.compact
      else
        cleaned
      end
    end

    def time(t)
      t&.to_time&.utc&.iso8601
    end

    # Deep-converts BSON/Mongoid values into JSON-safe ones.
    def clean(value)
      case value
      when Hash
        value.each_with_object({}) {|(k, v), h| h[k.to_s] = clean(v) }
      when Array
        value.map {|v| clean(v) }
      when BSON::ObjectId, Symbol
        value.to_s
      when Time, DateTime, Date
        time(value)
      when BigDecimal
        value.to_f
      else
        value
      end
    end
  end
end
