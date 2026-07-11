require 'json'
require_relative 'errors'
require_relative 'tool_registry'
require_relative 'tools/simulator_tools'
require_relative 'tools/host_tools'
require_relative 'tools/parameter_set_tools'
require_relative 'tools/run_tools'
require_relative 'tools/analysis_tools'
require_relative 'tools/file_tools'

module McpServer

  # A minimal MCP server: newline-delimited JSON-RPC 2.0 over stdio.
  # Supports initialize / ping / tools/list / tools/call, which is the
  # complete surface needed by MCP clients for a tools-only server.
  class Server

    PROTOCOL_VERSION = "2025-06-18"
    SUPPORTED_PROTOCOL_VERSIONS = ["2025-06-18", "2025-03-26", "2024-11-05"].freeze

    TOOL_MODULES = [
      Tools::SimulatorTools,
      Tools::HostTools,
      Tools::ParameterSetTools,
      Tools::RunTools,
      Tools::AnalysisTools,
      Tools::FileTools
    ].freeze

    def self.build_registry(**registry_options)
      registry = ToolRegistry.new(**registry_options)
      TOOL_MODULES.each {|mod| mod.register(registry) }
      registry
    end

    def initialize(input:, output:, registry: nil, logger: nil)
      @input = input
      @output = output
      @registry = registry || self.class.build_registry
      @logger = logger
    end

    def run
      @input.each_line do |line|
        line = line.strip
        next if line.empty?
        handle_line(line)
      end
    end

    def handle_line(line)
      begin
        message = JSON.parse(line)
      rescue JSON::ParserError
        write_error(nil, -32700, "Parse error")
        return
      end
      # notifications (no id) require no response
      return if message["id"].nil?
      handle_request(message)
    end

    private
    def handle_request(message)
      id = message["id"]
      params = message["params"] || {}
      case message["method"]
      when "initialize"
        write_result(id, initialize_result(params))
      when "ping"
        write_result(id, {})
      when "tools/list"
        write_result(id, { "tools" => @registry.visible_tools })
      when "tools/call"
        write_result(id, call_tool(params))
      else
        write_error(id, -32601, "Method not found: #{message["method"]}")
      end
    rescue UnknownToolError, InvalidArgumentsError => e
      write_error(id, -32602, e.message)
    rescue => e
      log_exception(e)
      write_error(id, -32603, "Internal error: #{e.class}")
    end

    def initialize_result(params)
      client_version = params["protocolVersion"]
      version = SUPPORTED_PROTOCOL_VERSIONS.include?(client_version) ? client_version : PROTOCOL_VERSION
      {
        "protocolVersion" => version,
        "capabilities" => { "tools" => {} },
        "serverInfo" => { "name" => "oacis", "version" => oacis_version }
      }
    end

    def call_tool(params)
      payload = @registry.call(params["name"], params["arguments"])
      tool_result(payload, is_error: false)
    rescue UnknownToolError, InvalidArgumentsError
      raise  # protocol-level: mapped to -32602 by the caller
    rescue => e
      tool_error = Errors.wrap(e)
      log_exception(e) if tool_error.code == "internal_error"
      tool_result(tool_error.to_h, is_error: true)
    end

    def tool_result(payload, is_error:)
      {
        "content" => [{ "type" => "text", "text" => JSON.pretty_generate(payload) }],
        "isError" => is_error
      }
    end

    def write_result(id, result)
      write("jsonrpc" => "2.0", "id" => id, "result" => result)
    end

    def write_error(id, code, message)
      write("jsonrpc" => "2.0", "id" => id, "error" => { "code" => code, "message" => message })
    end

    def write(hash)
      @output.puts(JSON.generate(hash))
      @output.flush
    end

    def oacis_version
      defined?(::APP_VERSION) ? ::APP_VERSION.to_s.strip : ""
    end

    def log_exception(e)
      return unless @logger
      @logger.error("#{e.class}: #{e.message}\n  #{Array(e.backtrace).first(10).join("\n  ")}")
    end
  end
end
