require 'spec_helper'
require Rails.root.join('lib/mcp_server/server')

describe "McpServer file tools" do

  let(:registry) { McpServer::Server.build_registry(access_level: 2, read_only: false) }

  before(:each) do
    sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1, analyzers_count: 0)
    @run = sim.parameter_sets.first.runs.first
    File.write(@run.dir.join("_stdout.txt"), "hello\nworld\n")
    FileUtils.mkdir_p(@run.dir.join("data"))
    File.write(@run.dir.join("data", "series.csv"), "1,2\n3,4\n")
  end

  describe "list_result_files" do
    it "lists files and directories with metadata" do
      result = registry.call("list_result_files", {"run_id" => @run.id.to_s})
      paths = result["entries"].map {|e| e["path"] }
      expect(paths).to include("_stdout.txt", "data")
      stdout_entry = result["entries"].detect {|e| e["path"] == "_stdout.txt" }
      expect(stdout_entry["directory"]).to be false
      expect(stdout_entry["size"]).to eq 12
      expect(result["truncated"]).to be false
    end

    it "descends into subdirectories via relative_path" do
      result = registry.call("list_result_files", {"run_id" => @run.id.to_s, "relative_path" => "data"})
      expect(result["entries"].map {|e| e["path"] }).to eq ["data/series.csv"]
    end

    it "requires exactly one of run_id and analysis_id" do
      expect { registry.call("list_result_files", {}) }.to raise_error(McpServer::InvalidArgumentsError)
    end

    it "reports base_dir through OACIS_MCP_DIR_MAP" do
      ENV['OACIS_MCP_DIR_MAP'] = "#{ResultDirectory.root}=/host/Result"
      begin
        result = registry.call("list_result_files", {"run_id" => @run.id.to_s})
        expect(result["base_dir"]).to eq @run.dir.to_s.sub(ResultDirectory.root.to_s, "/host/Result")
      ensure
        ENV.delete('OACIS_MCP_DIR_MAP')
      end
    end
  end

  describe "read_result_file" do
    it "reads a text file" do
      result = registry.call("read_result_file", {"run_id" => @run.id.to_s, "path" => "_stdout.txt"})
      expect(result["content"]).to eq "hello\nworld\n"
      expect(result["truncated"]).to be false
      expect(result["size"]).to eq 12
    end

    it "pages through a file with offset_bytes and max_bytes" do
      first = registry.call("read_result_file",
                            {"run_id" => @run.id.to_s, "path" => "_stdout.txt", "max_bytes" => 6})
      expect(first["content"]).to eq "hello\n"
      expect(first["truncated"]).to be true
      rest = registry.call("read_result_file",
                           {"run_id" => @run.id.to_s, "path" => "_stdout.txt", "offset_bytes" => 6})
      expect(rest["content"]).to eq "world\n"
      expect(rest["truncated"]).to be false
    end

    it "rejects binary files" do
      File.binwrite(@run.dir.join("blob.bin"), "\x00\x01\x02")
      expect {
        registry.call("read_result_file", {"run_id" => @run.id.to_s, "path" => "blob.bin"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "binary_file" }
    end

    it "raises not_found for a missing file" do
      expect {
        registry.call("read_result_file", {"run_id" => @run.id.to_s, "path" => "nope.txt"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "not_found" }
    end
  end

  describe "path traversal protection" do
    it "rejects ../ escapes" do
      # the parent (parameter set) directory exists, so realpath succeeds and the guard must catch it
      expect {
        registry.call("list_result_files", {"run_id" => @run.id.to_s, "relative_path" => ".."})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_path" }
      expect {
        registry.call("read_result_file", {"run_id" => @run.id.to_s, "path" => "../../../../etc/hosts"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_path" }
    end

    it "rejects absolute paths outside the result directory" do
      expect {
        registry.call("read_result_file", {"run_id" => @run.id.to_s, "path" => "/etc/hosts"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_path" }
    end

    it "rejects symlinks pointing outside the result directory" do
      File.symlink("/etc", @run.dir.join("escape"))
      expect {
        registry.call("list_result_files", {"run_id" => @run.id.to_s, "relative_path" => "escape"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_path" }
      File.symlink("/etc/hosts", @run.dir.join("escape_file"))
      expect {
        registry.call("read_result_file", {"run_id" => @run.id.to_s, "path" => "escape_file"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_path" }
    end

    it "allows symlinks that stay inside the result directory" do
      File.symlink(@run.dir.join("_stdout.txt"), @run.dir.join("alias.txt"))
      result = registry.call("read_result_file", {"run_id" => @run.id.to_s, "path" => "alias.txt"})
      expect(result["content"]).to eq "hello\nworld\n"
    end
  end
end
