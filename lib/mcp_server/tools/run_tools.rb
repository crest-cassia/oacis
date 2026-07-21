require_relative 'common'

module McpServer
  module Tools
    module RunTools
      extend Common

      MAX_NUM_RUNS_PER_CALL = 100

      def self.register(registry)
        register_get(registry)
        register_list(registry)
        register_create(registry)
      end

      def self.register_get(registry)
        registry.register(
          "get_run",
          description: "Get one run: status, destination host, host parameters, seed, timings, error messages, " \
                       "and the parsed result values once finished. 'dir' is the run's result directory; " \
                       "if it is accessible from your filesystem (local or Docker-mounted OACIS), read the " \
                       "output files there directly — including binary ones such as plot images. " \
                       "Fall back to list_result_files/read_result_file only when the path is not accessible.",
          input_schema: {
            "type" => "object",
            "properties" => { "run_id" => { "type" => "string" } },
            "required" => ["run_id"]
          }
        ) do |args|
          run = Resolvers.run(args["run_id"])
          Serializers.run(run).merge("v" => Serializers.clean(run.parameter_set.v))
        end
      end

      def self.register_list(registry)
        registry.register(
          "list_runs",
          description: "List runs of a parameter set or of a whole simulator, optionally filtered by status. " \
                       "Useful to find failed runs (status: failed) or count progress.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "parameter_set_id" => { "type" => "string" },
              "simulator" => { "type" => "string", "description" => "Simulator name or id (alternative to parameter_set_id)" },
              "status" => { "type" => "string", "enum" => %w[created submitted running failed finished] }
            }.merge(Common::PAGINATION_PROPERTIES),
            "required" => []
          }
        ) do |args|
          scope_key = exactly_one_of!(args.slice("parameter_set_id", "simulator"), "parameter_set_id", "simulator")
          query =
            if scope_key == "parameter_set_id"
              Resolvers.parameter_set(args["parameter_set_id"]).runs
            else
              Resolvers.simulator(args["simulator"]).runs
            end
          query = query.where(status: args["status"].to_sym) if args["status"]
          limit, offset = pagination(args)
          total = query.count
          runs = query.asc(:created_at).skip(offset).limit(limit).to_a
          {
            "total" => total,
            "offset" => offset,
            "runs" => runs.map {|r| Serializers.run(r, brief: true).merge("parameter_set_id" => r.parameter_set_id.to_s) }
          }
        end
      end

      def self.register_create(registry)
        registry.register(
          "create_runs",
          description: "Ensure a parameter set has num_runs runs (idempotent 'up to' semantics: existing runs count " \
                       "toward the total and only the shortfall is created). New runs start with status 'created' " \
                       "and are submitted asynchronously by OACIS's background daemons via SSH — expect a delay; " \
                       "poll get_parameter_set or list_runs every ~30-60 seconds rather than immediately. " \
                       "Specify either a host or a host_group as destination. host_parameters defaults to the " \
                       "host's default values (see list_hosts).",
          input_schema: {
            "type" => "object",
            "properties" => {
              "parameter_set_id" => { "type" => "string" },
              "num_runs" => { "type" => "integer", "description" => "Desired total number of runs on this parameter set (1-#{MAX_NUM_RUNS_PER_CALL})" },
              "host" => { "type" => "string", "description" => "Destination host name or id (give either this or host_group)" },
              "host_group" => { "type" => "string", "description" => "Destination host group name or id" },
              "host_parameters" => { "type" => "object", "description" => "Scheduler parameters, e.g. {\"ppn\": \"4\", \"walltime\": \"1:00:00\"}; must match the host's host_parameter_definitions" },
              "mpi_procs" => { "type" => "integer" },
              "omp_threads" => { "type" => "integer" },
              "priority" => { "type" => "integer", "enum" => [0, 1, 2], "description" => "0 = high, 1 = normal (default), 2 = low" }
            },
            "required" => ["parameter_set_id", "num_runs"]
          },
          write: true
        ) do |args|
          ps = Resolvers.parameter_set(args["parameter_set_id"])
          num_runs = args["num_runs"]
          unless (1..MAX_NUM_RUNS_PER_CALL).cover?(num_runs)
            raise InvalidArgumentsError, "num_runs must be between 1 and #{MAX_NUM_RUNS_PER_CALL}"
          end
          destination = exactly_one_of!(args.slice("host", "host_group"), "host", "host_group")
          host = destination == "host" ? Resolvers.host(args["host"]) : nil
          host_group = destination == "host_group" ? Resolvers.host_group(args["host_group"]) : nil

          sim = ps.simulator
          mpi_procs = args["mpi_procs"] || 1
          omp_threads = args["omp_threads"] || 1
          clamped = []
          if !sim.support_mpi && mpi_procs != 1
            mpi_procs = 1
            clamped << "mpi_procs clamped to 1 (simulator does not support MPI)"
          end
          if !sim.support_omp && omp_threads != 1
            omp_threads = 1
            clamped << "omp_threads clamped to 1 (simulator does not support OpenMP)"
          end

          num_before = ps.runs.count
          runs = ps.find_or_create_runs_upto(num_runs,
                                             submitted_to: host,
                                             host_param: args["host_parameters"],
                                             host_group: host_group,
                                             mpi_procs: mpi_procs,
                                             omp_threads: omp_threads,
                                             priority: args["priority"] || 1)
          created_count = runs.size - [num_before, num_runs].min
          found_count = runs.size - created_count
          response = {
            "runs" => runs.each_with_index.map do |r, i|
              Serializers.run(r, brief: true).merge("created" => i >= found_count)
            end,
            "created_count" => created_count,
            "total_runs_now" => ps.runs.count
          }
          response["notes"] = clamped unless clamped.empty?
          response
        end
      end
    end
  end
end
