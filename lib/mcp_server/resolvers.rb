require_relative 'errors'

module McpServer

  # Resolves tool arguments to documents.
  # Simulators, hosts, host groups and analyzers accept a name or an id;
  # parameter sets, runs, and analyses are id-only.
  module Resolvers

    module_function

    def simulator(name_or_id)
      by_name_or_id(Simulator, name_or_id, "Simulator", "list_simulators")
    end

    def host(name_or_id)
      by_name_or_id(Host, name_or_id, "Host", "list_hosts")
    end

    def host_group(name_or_id)
      by_name_or_id(HostGroup, name_or_id, "HostGroup", "list_hosts")
    end

    def analyzer(simulator, name_or_id)
      if BSON::ObjectId.legal?(name_or_id)
        azr = Analyzer.find(name_or_id)
        unless azr.simulator_id == simulator.id
          raise ToolError.new("invalid_arguments",
                              "Analyzer #{name_or_id} does not belong to simulator #{simulator.name}")
        end
        azr
      else
        simulator.find_analyzer_by_name(name_or_id)
      end
    rescue Mongoid::Errors::DocumentNotFound, RuntimeError => e
      raise e if e.is_a?(ToolError)
      raise ToolError.new("not_found", "Analyzer '#{name_or_id}' is not found",
                          hint: "Call list_simulators to see the analyzers of each simulator.")
    end

    def parameter_set(id)
      by_id(ParameterSet, id, "ParameterSet", "search_parameter_sets")
    end

    def run(id)
      by_id(Run, id, "Run", "list_runs")
    end

    def analysis(id)
      by_id(Analysis, id, "Analysis", "list_analyses")
    end

    def by_name_or_id(klass, name_or_id, label, list_tool)
      if BSON::ObjectId.legal?(name_or_id)
        klass.find(name_or_id)
      else
        klass.find_by_name(name_or_id)
      end
    rescue Mongoid::Errors::DocumentNotFound, RuntimeError
      raise ToolError.new("not_found", "#{label} '#{name_or_id}' is not found",
                          hint: "Call #{list_tool} to see available #{label.downcase}s.")
    end

    def by_id(klass, id, label, list_tool)
      unless BSON::ObjectId.legal?(id)
        raise ToolError.new("invalid_arguments",
                            "'#{id}' is not a valid #{label} id (24-char hex string expected)")
      end
      klass.find(id)
    rescue Mongoid::Errors::DocumentNotFound
      raise ToolError.new("not_found", "#{label} #{id} is not found",
                          hint: "Use #{list_tool} to find valid ids.")
    end
  end
end
