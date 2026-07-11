require_relative 'common'

module McpServer
  module Tools
    module AnalysisTools
      extend Common

      def self.register(registry)
        register_get(registry)
        register_list(registry)
        register_create(registry)
      end

      def self.register_get(registry)
        registry.register(
          "get_analysis",
          description: "Get one analysis: status, analyzer, target (run or parameter set), parameters, " \
                       "and the parsed result once finished. Use list_result_files/read_result_file " \
                       "with analysis_id to inspect its raw output files.",
          input_schema: {
            "type" => "object",
            "properties" => { "analysis_id" => { "type" => "string" } },
            "required" => ["analysis_id"]
          }
        ) do |args|
          Serializers.analysis(Resolvers.analysis(args["analysis_id"]))
        end
      end

      def self.register_list(registry)
        registry.register(
          "list_analyses",
          description: "List analyses on a run, on a parameter set (includes analyses on its runs), " \
                       "or of a whole simulator (optionally restricted to one analyzer). " \
                       "Filter by status to find failed or finished analyses.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "run_id" => { "type" => "string" },
              "parameter_set_id" => { "type" => "string" },
              "simulator" => { "type" => "string", "description" => "Simulator name or id" },
              "analyzer" => { "type" => "string", "description" => "Analyzer name or id (only with 'simulator')" },
              "status" => { "type" => "string", "enum" => %w[created submitted running failed finished] }
            }.merge(Common::PAGINATION_PROPERTIES),
            "required" => []
          }
        ) do |args|
          scope_key = exactly_one_of!(args.slice("run_id", "parameter_set_id", "simulator"),
                                      "run_id", "parameter_set_id", "simulator")
          query =
            case scope_key
            when "run_id"
              Resolvers.run(args["run_id"]).analyses
            when "parameter_set_id"
              ps = Resolvers.parameter_set(args["parameter_set_id"])
              Analysis.where(parameter_set_id: ps.id)
            else
              sim = Resolvers.simulator(args["simulator"])
              if args["analyzer"]
                Resolvers.analyzer(sim, args["analyzer"]).analyses
              else
                Analysis.in(analyzer_id: sim.analyzers.pluck(:id))
              end
            end
          query = query.where(status: args["status"].to_sym) if args["status"]
          limit, offset = pagination(args)
          total = query.count
          analyses = query.asc(:created_at).skip(offset).limit(limit).to_a
          {
            "total" => total,
            "offset" => offset,
            "analyses" => analyses.map {|a| Serializers.analysis(a, brief: true) }
          }
        end
      end

      def self.register_create(registry)
        registry.register(
          "create_analysis",
          description: "Create an analysis by running an analyzer on a finished run (analyzer type 'on_run') " \
                       "or on a parameter set with finished runs (type 'on_parameter_set'). Idempotent: if an " \
                       "analysis with the same analyzer and parameters already exists on the target, it is " \
                       "returned with created=false. Like runs, analyses start as 'created' and are executed " \
                       "asynchronously by the background daemons — poll get_analysis. " \
                       "Specify either a host or a host_group as destination.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "analyzer" => { "type" => "string", "description" => "Analyzer name or id (see list_simulators)" },
              "run_id" => { "type" => "string", "description" => "Target run (for analyzers of type on_run)" },
              "parameter_set_id" => { "type" => "string", "description" => "Target parameter set (for analyzers of type on_parameter_set)" },
              "parameters" => { "type" => "object", "description" => "Analyzer parameters; omitted keys use the analyzer's defaults" },
              "host" => { "type" => "string", "description" => "Destination host name or id (give either this or host_group)" },
              "host_group" => { "type" => "string", "description" => "Destination host group name or id" },
              "host_parameters" => { "type" => "object", "description" => "Scheduler parameters; must match the host's host_parameter_definitions" },
              "mpi_procs" => { "type" => "integer" },
              "omp_threads" => { "type" => "integer" },
              "priority" => { "type" => "integer", "enum" => [0, 1, 2], "description" => "0 = high, 1 = normal (default), 2 = low" }
            },
            "required" => ["analyzer"]
          },
          write: true
        ) do |args|
          target_key = exactly_one_of!(args.slice("run_id", "parameter_set_id"), "run_id", "parameter_set_id")
          if target_key == "run_id"
            target = Resolvers.run(args["run_id"])
            simulator = target.simulator
            expected_type = :on_run
          else
            target = Resolvers.parameter_set(args["parameter_set_id"])
            simulator = target.simulator
            expected_type = :on_parameter_set
          end
          analyzer = Resolvers.analyzer(simulator, args["analyzer"])
          if analyzer.type != expected_type
            other = expected_type == :on_run ? "parameter_set_id" : "run_id"
            raise ToolError.new("invalid_arguments",
                                "Analyzer '#{analyzer.name}' has type '#{analyzer.type}' — pass #{other} instead of #{target_key}")
          end
          check_target_finished!(target, expected_type)

          defaults = analyzer.parameter_definitions.map {|pd| [pd.key, pd.default] }.to_h
          merged = defaults.merge((args["parameters"] || {}).transform_keys(&:to_s))
          parameters = cast_parameters!(analyzer, merged, analyzer.parameter_definitions)

          existing = target.analyses.where(analyzer: analyzer, parameters: parameters).first
          if existing
            next Serializers.analysis(existing).merge("created" => false)
          end

          destination = exactly_one_of!(args.slice("host", "host_group"), "host", "host_group")
          host = destination == "host" ? Resolvers.host(args["host"]) : nil
          host_group = destination == "host_group" ? Resolvers.host_group(args["host_group"]) : nil

          mpi_procs = args["mpi_procs"] || 1
          omp_threads = args["omp_threads"] || 1
          mpi_procs = 1 unless analyzer.support_mpi
          omp_threads = 1 unless analyzer.support_omp

          anl = target.analyses.build(
            analyzer: analyzer,
            parameters: parameters,
            submitted_to: host,
            host_group: host_group,
            host_parameters: args["host_parameters"] || host&.default_host_parameters || {},
            mpi_procs: mpi_procs,
            omp_threads: omp_threads,
            priority: args["priority"] || 1
          )
          anl.save!
          Serializers.analysis(anl).merge("created" => true)
        end
      end

      def self.check_target_finished!(target, expected_type)
        if expected_type == :on_run && target.status != :finished
          raise ToolError.new("invalid_state",
                              "Run #{target.id} has status '#{target.status}'; analyses can only be created on finished runs",
                              hint: "Poll get_run until status is 'finished'.")
        end
        if expected_type == :on_parameter_set && target.runs.where(status: :finished).count == 0
          raise ToolError.new("invalid_state",
                              "ParameterSet #{target.id} has no finished runs yet; on_parameter_set analyzers need at least one",
                              hint: "Poll get_parameter_set until run_counts.finished > 0.")
        end
      end
    end
  end
end
