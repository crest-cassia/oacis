module McpServer

  # Raised by tool handlers. Serialized into the tools/call result body
  # (isError: true) so that the calling agent can read and act on it.
  class ToolError < StandardError
    attr_reader :code, :details, :hint

    def initialize(code, message, details: [], hint: nil)
      super(message)
      @code = code
      @details = details
      @hint = hint
    end

    def to_h
      h = { "error" => code, "message" => message }
      h["details"] = details if details.present?
      h["hint"] = hint if hint
      h
    end
  end

  # Protocol-level problems: mapped to JSON-RPC error -32602 by the server,
  # not to a tool result.
  class UnknownToolError < StandardError; end
  class InvalidArgumentsError < StandardError; end

  module Errors
    # Maps any exception raised by a tool handler to a ToolError.
    def self.wrap(exception)
      case exception
      when ToolError
        exception
      when Mongoid::Errors::Validations
        ToolError.new("validation_failed", "Validation failed: #{exception.document.class.name}",
                      details: exception.document.errors.full_messages,
                      hint: "Call list_hosts to see host_parameter_definitions (format regexps, defaults) and mpi/omp limits, or list_simulators for parameter_definitions.")
      when Mongoid::Errors::DocumentNotFound, BSON::Error::InvalidObjectId
        ToolError.new("not_found", exception.message.to_s.lines.first.to_s.strip,
                      hint: "Check the id, or use the corresponding list/search tool to find it.")
      when RuntimeError
        msg = exception.message.to_s
        if msg =~ /is not found\z/
          ToolError.new("not_found", msg, hint: "Use list_simulators or list_hosts to see available names.")
        elsif msg =~ /\A(Unknown keys|Missing keys)/
          ToolError.new("invalid_parameters", msg,
                        hint: "Call list_simulators to see the parameter_definitions of this simulator.")
        else
          internal(exception)
        end
      else
        internal(exception)
      end
    end

    def self.internal(exception)
      ToolError.new("internal_error", "#{exception.class}: #{exception.message}")
    end
  end
end
