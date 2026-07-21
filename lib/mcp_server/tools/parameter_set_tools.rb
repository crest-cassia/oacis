require_relative 'common'

module McpServer
  module Tools
    module ParameterSetTools
      extend Common

      RUNS_PREVIEW_LIMIT = 50

      def self.register(registry)
        register_search(registry)
        register_get(registry)
        register_find_or_create(registry)
      end

      def self.register_search(registry)
        registry.register(
          "search_parameter_sets",
          description: "Search the parameter sets of a simulator, optionally filtering by exact parameter values " \
                       "(a subset of keys is fine). Returns each parameter set with per-status run counts, " \
                       "so this is also the cheapest way to poll the progress of many parameter sets at once.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "simulator" => { "type" => "string", "description" => "Simulator name or id" },
              "v" => { "type" => "object", "description" => "Exact-match filter on parameter values, e.g. {\"p1\": 1, \"p2\": 2.0}. Keys may be a subset of the parameter definitions." }
            }.merge(Common::PAGINATION_PROPERTIES),
            "required" => ["simulator"]
          }
        ) do |args|
          sim = Resolvers.simulator(args["simulator"])
          query = sim.parameter_sets
          (args["v"] || {}).each do |key, value|
            pd = sim.parameter_definition_for(key.to_s)
            unless pd
              raise ToolError.new("invalid_parameters", "Unknown parameter key '#{key}'",
                                  hint: "Expected keys: #{sim.parameter_definitions.map(&:key).join(', ')}")
            end
            casted = ParametersUtil.cast_value(value, pd.type)
            if casted.nil?
              raise ToolError.new("invalid_parameters", "Value #{value.inspect} for '#{key}' cannot be cast to #{pd.type}")
            end
            query = query.where("v.#{key}" => casted)
          end
          limit, offset = pagination(args)
          total = query.count
          page = query.asc(:created_at).skip(offset).limit(limit).to_a
          counts = ParameterSet.runs_status_count_batch(page)
          {
            "total" => total,
            "offset" => offset,
            "parameter_sets" => page.map {|ps| Serializers.parameter_set(ps, run_counts: counts[ps.id]) }
          }
        end
      end

      def self.register_get(registry)
        registry.register(
          "get_parameter_set",
          description: "Get one parameter set with its run status counts, a preview of its runs and analyses, " \
                       "and optionally the average of each numeric result over finished runs " \
                       "(include_average_results). Poll this to track progress of the runs.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "parameter_set_id" => { "type" => "string" },
              "include_runs" => { "type" => "boolean", "description" => "Include a preview of runs (default true, first #{RUNS_PREVIEW_LIMIT})" },
              "include_average_results" => { "type" => "boolean", "description" => "Include {result_key => {average, count, error}} over finished runs (default false)" }
            },
            "required" => ["parameter_set_id"]
          }
        ) do |args|
          ps = Resolvers.parameter_set(args["parameter_set_id"])
          counts = ParameterSet.runs_status_count_batch([ps])[ps.id]
          h = Serializers.parameter_set(ps, run_counts: counts)
          h["dir"] = Serializers.map_dir(ps.dir)
          unless args["include_runs"] == false
            runs = ps.runs.asc(:created_at).limit(RUNS_PREVIEW_LIMIT).to_a
            h["runs"] = runs.map {|r| Serializers.run(r, brief: true) }
            h["runs_truncated"] = true if counts.values.sum > runs.size
          end
          analyses = ps.analyses.asc(:created_at).limit(RUNS_PREVIEW_LIMIT).to_a
          h["analyses"] = analyses.map {|a| Serializers.analysis(a, brief: true) }
          if args["include_average_results"]
            h["average_results"] = average_results(ps)
          end
          h
        end
      end

      def self.register_find_or_create(registry)
        registry.register(
          "find_or_create_parameter_set",
          description: "Find or create a parameter set of a simulator (idempotent). Give the parameter values in 'v'; " \
                       "omitted keys are filled with the simulator's defaults. Returns the parameter set and " \
                       "whether it was newly created. Creating a parameter set does not run anything — " \
                       "call create_runs on it afterwards.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "simulator" => { "type" => "string", "description" => "Simulator name or id" },
              "v" => { "type" => "object", "description" => "Parameter values, e.g. {\"p1\": 1, \"p2\": 2.0}" }
            },
            "required" => ["simulator", "v"]
          },
          write: true
        ) do |args|
          sim = Resolvers.simulator(args["simulator"])
          merged = sim.default_parameters.merge(args["v"])
          casted = cast_parameters!(sim, merged, sim.parameter_definitions)
          ps, created = ParameterSet.find_or_create!(sim, casted)
          if created
            Serializers.parameter_set(ps).merge("created" => true)
          else
            counts = ParameterSet.runs_status_count_batch([ps])[ps.id]
            Serializers.parameter_set(ps, run_counts: counts).merge("created" => false)
          end
        end
      end

      def self.average_results(ps)
        first_finished = ps.runs.where(status: :finished).first
        result = first_finished&.result
        return {} unless result.is_a?(Hash)
        numeric_keys = result.select {|_k, v| v.is_a?(Numeric) }.keys
        numeric_keys.each_with_object({}) do |key, h|
          average, count, error = ps.average_result(key, error: true)
          h[key] = { "average" => average, "count" => count, "error" => error }
        end
      end
    end
  end
end
