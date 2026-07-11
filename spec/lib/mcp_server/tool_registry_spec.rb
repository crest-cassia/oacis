require 'spec_helper'
require Rails.root.join('lib/mcp_server/tool_registry')

describe McpServer::ToolRegistry do

  def build_registry(access_level: 2, read_only: false)
    registry = McpServer::ToolRegistry.new(access_level: access_level, read_only: read_only)
    registry.register("read_tool",
                      description: "a read tool",
                      input_schema: {
                        "type" => "object",
                        "properties" => {
                          "name" => { "type" => "string" },
                          "count" => { "type" => "integer" },
                          "status" => { "type" => "string", "enum" => ["a", "b"] }
                        },
                        "required" => ["name"]
                      }) {|args| { "echo" => args } }
    registry.register("write_tool",
                      description: "a write tool",
                      input_schema: { "type" => "object", "properties" => {} },
                      write: true) {|_args| { "wrote" => true } }
    registry
  end

  describe "#visible_tools" do
    it "lists all tools with name, description, and inputSchema" do
      tools = build_registry.visible_tools
      expect(tools.map {|t| t["name"] }).to match_array ["read_tool", "write_tool"]
      expect(tools.first).to include("description", "inputSchema")
    end

    it "hides write tools when access level is 0" do
      tools = build_registry(access_level: 0).visible_tools
      expect(tools.map {|t| t["name"] }).to eq ["read_tool"]
    end

    it "hides write tools in read-only mode regardless of access level" do
      tools = build_registry(access_level: 2, read_only: true).visible_tools
      expect(tools.map {|t| t["name"] }).to eq ["read_tool"]
    end
  end

  describe "#call" do
    it "invokes the handler with the given arguments" do
      expect(build_registry.call("read_tool", {"name" => "x"})).to eq({ "echo" => { "name" => "x" } })
    end

    it "raises UnknownToolError for an unregistered tool" do
      expect {
        build_registry.call("no_such_tool", {})
      }.to raise_error(McpServer::UnknownToolError)
    end

    it "denies write tools when not writable" do
      expect {
        build_registry(access_level: 0).call("write_tool", {})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "permission_denied" }
    end

    it "allows write tools when writable" do
      expect(build_registry.call("write_tool", {})).to eq({ "wrote" => true })
    end

    describe "argument validation" do
      it "rejects missing required arguments" do
        expect {
          build_registry.call("read_tool", {})
        }.to raise_error(McpServer::InvalidArgumentsError, /missing required/)
      end

      it "rejects unknown arguments" do
        expect {
          build_registry.call("read_tool", {"name" => "x", "bogus" => 1})
        }.to raise_error(McpServer::InvalidArgumentsError, /unknown argument/)
      end

      it "rejects arguments of the wrong type" do
        expect {
          build_registry.call("read_tool", {"name" => "x", "count" => "many"})
        }.to raise_error(McpServer::InvalidArgumentsError, /must be of type integer/)
      end

      it "rejects values outside an enum" do
        expect {
          build_registry.call("read_tool", {"name" => "x", "status" => "c"})
        }.to raise_error(McpServer::InvalidArgumentsError, /must be one of/)
      end
    end
  end
end
