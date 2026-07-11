require_relative 'common'

module McpServer
  module Tools
    module SimulatorTools
      extend Common

      def self.register(registry)
        registry.register(
          "list_simulators",
          description: "List the simulators registered on OACIS, with their parameter definitions " \
                       "(key, type, default), analyzers, executable hosts, and run status counts. " \
                       "Call this first to learn what can be simulated and which parameters a simulator takes.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "name_contains" => { "type" => "string", "description" => "Filter simulators whose name contains this substring (case-insensitive)" }
            }
          }
        ) do |args|
          sims = Simulator.asc(:position).to_a
          if args["name_contains"]
            pattern = Regexp.new(Regexp.escape(args["name_contains"]), Regexp::IGNORECASE)
            sims = sims.select {|s| s.name =~ pattern }
          end
          counts = Simulator.runs_status_count_batch(sims)
          {
            "total" => sims.size,
            "simulators" => sims.map {|s| Serializers.simulator(s, runs_status_count: counts[s.id]) }
          }
        end
      end
    end
  end
end
