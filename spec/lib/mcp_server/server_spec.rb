require 'spec_helper'
require Rails.root.join('lib/mcp_server/server')

describe McpServer::Server do

  def run_server(requests, access_level: 2)
    input = StringIO.new(requests.map {|r| JSON.generate(r) }.join("\n") + "\n")
    output = StringIO.new
    registry = McpServer::Server.build_registry(access_level: access_level, read_only: false)
    McpServer::Server.new(input: input, output: output, registry: registry).run
    output.string.each_line.map {|line| JSON.parse(line) }
  end

  def request(id, method, params = {})
    { "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params }
  end

  it "answers the initialize handshake with server info and tools capability" do
    responses = run_server([request(1, "initialize", {"protocolVersion" => "2025-06-18"})])
    result = responses.first["result"]
    expect(result["protocolVersion"]).to eq "2025-06-18"
    expect(result["capabilities"]).to have_key "tools"
    expect(result["serverInfo"]["name"]).to eq "oacis"
  end

  it "answers ping" do
    responses = run_server([request(1, "ping")])
    expect(responses.first["result"]).to eq({})
  end

  it "lists all 13 tools at full access level" do
    responses = run_server([request(1, "tools/list")])
    tools = responses.first["result"]["tools"]
    expect(tools.size).to eq 13
    expect(tools.first).to include("name", "description", "inputSchema")
  end

  it "hides the 3 write tools at access level 0" do
    responses = run_server([request(1, "tools/list")], access_level: 0)
    tools = responses.first["result"]["tools"]
    expect(tools.size).to eq 10
    expect(tools.map {|t| t["name"] }).not_to include("create_runs", "find_or_create_parameter_set", "create_analysis")
  end

  it "executes a tool call and returns its payload as text content" do
    FactoryBot.create(:host)
    responses = run_server([request(1, "tools/call", {"name" => "list_hosts", "arguments" => {}})])
    result = responses.first["result"]
    expect(result["isError"]).to be false
    payload = JSON.parse(result["content"].first["text"])
    expect(payload["hosts"].size).to eq 1
  end

  it "returns a structured isError result when a tool fails" do
    responses = run_server([request(1, "tools/call",
                                    {"name" => "get_run", "arguments" => {"run_id" => "0" * 24}})])
    result = responses.first["result"]
    expect(result["isError"]).to be true
    payload = JSON.parse(result["content"].first["text"])
    expect(payload["error"]).to eq "not_found"
    expect(payload).to have_key "hint"
  end

  it "returns a permission_denied tool error for write tools at access level 0" do
    responses = run_server([request(1, "tools/call",
                                    {"name" => "create_runs",
                                     "arguments" => {"parameter_set_id" => "0" * 24, "num_runs" => 1}})],
                           access_level: 0)
    result = responses.first["result"]
    expect(result["isError"]).to be true
    payload = JSON.parse(result["content"].first["text"])
    expect(payload["error"]).to eq "permission_denied"
  end

  it "maps unknown tools and invalid arguments to JSON-RPC -32602" do
    responses = run_server([
      request(1, "tools/call", {"name" => "no_such_tool", "arguments" => {}}),
      request(2, "tools/call", {"name" => "get_run", "arguments" => {}})
    ])
    expect(responses[0]["error"]["code"]).to eq(-32602)
    expect(responses[1]["error"]["code"]).to eq(-32602)
    expect(responses[1]["error"]["message"]).to match(/missing required/)
  end

  it "maps unknown methods to -32601" do
    responses = run_server([request(1, "resources/list")])
    expect(responses.first["error"]["code"]).to eq(-32601)
  end

  it "maps malformed JSON to -32700 and keeps serving" do
    input = StringIO.new("this is not json\n" + JSON.generate(request(2, "ping")) + "\n")
    output = StringIO.new
    registry = McpServer::Server.build_registry(access_level: 2, read_only: false)
    McpServer::Server.new(input: input, output: output, registry: registry).run
    responses = output.string.each_line.map {|line| JSON.parse(line) }
    expect(responses[0]["error"]["code"]).to eq(-32700)
    expect(responses[1]["result"]).to eq({})
  end

  it "ignores notifications (messages without an id)" do
    responses = run_server([
      { "jsonrpc" => "2.0", "method" => "notifications/initialized" },
      request(1, "ping")
    ])
    expect(responses.size).to eq 1
    expect(responses.first["id"]).to eq 1
  end

  it "survives a handler exception and reports it as a tool error" do
    registry = McpServer::Server.build_registry(access_level: 2, read_only: false)
    registry.register("boom", description: "raises", input_schema: {"type" => "object", "properties" => {}}) do
      raise "kaboom"
    end
    input = StringIO.new(
      JSON.generate(request(1, "tools/call", {"name" => "boom", "arguments" => {}})) + "\n" +
      JSON.generate(request(2, "ping")) + "\n"
    )
    output = StringIO.new
    McpServer::Server.new(input: input, output: output, registry: registry).run
    responses = output.string.each_line.map {|line| JSON.parse(line) }
    expect(responses[0]["result"]["isError"]).to be true
    payload = JSON.parse(responses[0]["result"]["content"].first["text"])
    expect(payload["error"]).to eq "internal_error"
    expect(responses[1]["result"]).to eq({})
  end
end
