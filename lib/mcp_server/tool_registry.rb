require_relative 'errors'

module McpServer

  # Holds tool definitions (name -> schema + handler) and enforces
  # write-permission gating and input validation.
  class ToolRegistry

    Tool = Struct.new(:name, :description, :input_schema, :write, :handler, keyword_init: true)

    TYPE_CHECKS = {
      "string"  => ->(v) { v.is_a?(String) },
      "integer" => ->(v) { v.is_a?(Integer) },
      "number"  => ->(v) { v.is_a?(Numeric) },
      "boolean" => ->(v) { v == true || v == false },
      "object"  => ->(v) { v.is_a?(Hash) },
      "array"   => ->(v) { v.is_a?(Array) }
    }.freeze

    def initialize(access_level: OACIS_ACCESS_LEVEL, read_only: ENV['OACIS_MCP_READONLY'] == '1')
      @tools = {}
      @writable = access_level.to_i >= 1 && !read_only
    end

    def writable?
      @writable
    end

    def register(name, description:, input_schema:, write: false, &handler)
      @tools[name] = Tool.new(name: name, description: description,
                              input_schema: input_schema, write: write, handler: handler)
    end

    # Tool list for tools/list. Write tools are hidden when not writable.
    def visible_tools
      @tools.values.reject {|t| t.write && !@writable }.map do |t|
        { "name" => t.name, "description" => t.description, "inputSchema" => t.input_schema }
      end
    end

    def call(name, arguments)
      tool = @tools[name]
      raise UnknownToolError, "Unknown tool: #{name}" unless tool
      if tool.write && !@writable
        raise ToolError.new("permission_denied",
                            "Tool '#{name}' modifies data and is disabled on this server " \
                            "(OACIS_ACCESS_LEVEL is 0 or OACIS_MCP_READONLY is set)")
      end
      arguments ||= {}
      raise InvalidArgumentsError, "arguments must be an object" unless arguments.is_a?(Hash)
      validate_arguments!(tool, arguments)
      tool.handler.call(arguments)
    end

    private
    def validate_arguments!(tool, args)
      schema = tool.input_schema
      properties = schema["properties"] || {}
      required = schema["required"] || []

      missing = required - args.keys
      unless missing.empty?
        raise InvalidArgumentsError, "#{tool.name}: missing required argument(s): #{missing.join(', ')}"
      end
      unknown = args.keys - properties.keys
      unless unknown.empty?
        raise InvalidArgumentsError,
              "#{tool.name}: unknown argument(s): #{unknown.join(', ')} (accepted: #{properties.keys.join(', ')})"
      end
      args.each do |key, value|
        prop = properties[key]
        type_check = TYPE_CHECKS[prop["type"]]
        if type_check && !type_check.call(value)
          raise InvalidArgumentsError, "#{tool.name}: argument '#{key}' must be of type #{prop['type']}"
        end
        if prop["enum"] && !prop["enum"].include?(value)
          raise InvalidArgumentsError,
                "#{tool.name}: argument '#{key}' must be one of #{prop['enum'].join(', ')}"
        end
      end
    end
  end
end
