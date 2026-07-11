require_relative 'common'

module McpServer
  module Tools
    module HostTools
      extend Common

      def self.register(registry)
        registry.register(
          "list_hosts",
          description: "List the computation hosts and host groups jobs can be submitted to. " \
                       "Each host lists its host_parameter_definitions: when creating runs or analyses, " \
                       "host_parameters must include each key, matching its 'format' regexp (or one of 'options'). " \
                       "mpi_procs/omp_threads must lie within the host's min/max. " \
                       "A run needs either a host or a host_group as its destination.",
          input_schema: { "type" => "object", "properties" => {} }
        ) do |_args|
          {
            "hosts" => Host.asc(:position).map {|h| Serializers.host(h) },
            "host_groups" => HostGroup.all.map {|hg| Serializers.host_group(hg) }
          }
        end
      end
    end
  end
end
