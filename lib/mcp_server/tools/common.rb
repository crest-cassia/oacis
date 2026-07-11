require_relative '../errors'
require_relative '../resolvers'
require_relative '../serializers'

module McpServer
  module Tools
    module Common

      DEFAULT_LIMIT = 25
      MAX_LIMIT = 200

      PAGINATION_PROPERTIES = {
        "limit" => { "type" => "integer", "description" => "Max items to return (default #{DEFAULT_LIMIT}, max #{MAX_LIMIT})" },
        "offset" => { "type" => "integer", "description" => "Number of items to skip (default 0)" }
      }.freeze

      def pagination(args)
        limit = (args["limit"] || DEFAULT_LIMIT).clamp(1, MAX_LIMIT)
        offset = [args["offset"].to_i, 0].max
        [limit, offset]
      end

      # Requires that exactly one of the given keys is present in args.
      def exactly_one_of!(args, *keys)
        given = keys.select {|k| args.key?(k) }
        unless given.size == 1
          raise InvalidArgumentsError, "exactly one of #{keys.join(', ')} must be given"
        end
        given.first
      end

      # Casts user-given parameter values against embedded parameter definitions,
      # raising a structured error listing every problem.
      def cast_parameters!(owner, parameters, definitions)
        errs = ActiveModel::Errors.new(owner)
        casted = ParametersUtil.cast_parameter_values(parameters, definitions, errs)
        if errs.any? || casted.nil?
          raise ToolError.new("invalid_parameters", "Invalid parameter values",
                              details: errs.full_messages,
                              hint: "Expected keys: #{definitions.map(&:key).join(', ')}. " \
                                    "See parameter_definitions from list_simulators.")
        end
        casted
      end
    end
  end
end
