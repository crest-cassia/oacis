require 'spec_helper'
require Rails.root.join('lib/mcp_server/server')

describe "McpServer write tools" do

  let(:registry) { McpServer::Server.build_registry(access_level: 2, read_only: false) }

  describe "find_or_create_parameter_set" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 0, runs_count: 0, analyzers_count: 0)
    end

    it "creates a new parameter set, filling omitted keys with defaults" do
      result = registry.call("find_or_create_parameter_set", {"simulator" => @sim.name, "v" => {"L" => 10}})
      expect(result["created"]).to be true
      expect(result["v"]).to eq({"L" => 10, "T" => 1.0})
      expect(@sim.parameter_sets.count).to eq 1
    end

    it "is idempotent: returns the existing parameter set with created=false" do
      first = registry.call("find_or_create_parameter_set", {"simulator" => @sim.name, "v" => {"L" => 10, "T" => 2.0}})
      second = registry.call("find_or_create_parameter_set", {"simulator" => @sim.name, "v" => {"L" => 10, "T" => 2.0}})
      expect(second["created"]).to be false
      expect(second["id"]).to eq first["id"]
      expect(@sim.parameter_sets.count).to eq 1
    end

    it "casts string values to the defined types" do
      result = registry.call("find_or_create_parameter_set", {"simulator" => @sim.name, "v" => {"L" => "10", "T" => "2.0"}})
      expect(result["v"]).to eq({"L" => 10, "T" => 2.0})
    end

    it "rejects unknown parameter keys with a structured error" do
      expect {
        registry.call("find_or_create_parameter_set", {"simulator" => @sim.name, "v" => {"bogus" => 1}})
      }.to raise_error(McpServer::ToolError) {|e|
        expect(e.code).to eq "invalid_parameters"
        expect(e.details.join).to match(/bogus/)
      }
    end

    it "rejects uncastable values" do
      expect {
        registry.call("find_or_create_parameter_set", {"simulator" => @sim.name, "v" => {"L" => "abc"}})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_parameters" }
    end
  end

  describe "create_runs" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0, analyzers_count: 0)
      @ps = @sim.parameter_sets.first
      @host = @sim.executable_on.first
    end

    it "creates runs up to num_runs with status created" do
      result = registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 3, "host" => @host.name})
      expect(result["created_count"]).to eq 3
      expect(result["total_runs_now"]).to eq 3
      expect(result["runs"].map {|r| r["status"] }.uniq).to eq ["created"]
      expect(result["runs"].map {|r| r["created"] }.uniq).to eq [true]
    end

    it "is idempotent: existing runs count toward the total" do
      registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 3, "host" => @host.name})
      result = registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 3, "host" => @host.name})
      expect(result["created_count"]).to eq 0
      result = registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 5, "host" => @host.name})
      expect(result["created_count"]).to eq 2
      expect(result["runs"].count {|r| r["created"] }).to eq 2
      expect(@ps.reload.runs.count).to eq 5
    end

    it "requires exactly one of host and host_group" do
      hg = FactoryBot.create(:host_group)
      expect {
        registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 1})
      }.to raise_error(McpServer::InvalidArgumentsError)
      expect {
        registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 1,
                                      "host" => @host.name, "host_group" => hg.name})
      }.to raise_error(McpServer::InvalidArgumentsError)
    end

    it "accepts a host_group as destination" do
      hg = FactoryBot.create(:host_group)
      result = registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 1, "host_group" => hg.name})
      expect(result["created_count"]).to eq 1
      expect(result["runs"].first["host_group"]).to eq hg.name
    end

    it "caps num_runs" do
      expect {
        registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 101, "host" => @host.name})
      }.to raise_error(McpServer::InvalidArgumentsError, /between 1 and 100/)
    end

    it "clamps mpi_procs when the simulator does not support MPI" do
      result = registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 1,
                                             "host" => @host.name, "mpi_procs" => 4})
      expect(result["notes"].join).to match(/mpi_procs clamped/)
      expect(@ps.runs.first.mpi_procs).to eq 1
    end

    it "surfaces host_parameters validation failures with the expected format" do
      host = FactoryBot.create(:host_with_parameters)
      host.host_parameter_definitions.first.format = '^\d+$'
      host.host_parameter_definitions.first.default = "8"
      host.save!
      exception = nil
      begin
        registry.call("create_runs", {"parameter_set_id" => @ps.id.to_s, "num_runs" => 1,
                                      "host" => host.name,
                                      "host_parameters" => {"param1" => "abc", "param2" => "XXX"}})
      rescue => e
        exception = e
      end
      expect(exception).to be_a Mongoid::Errors::Validations
      wrapped = McpServer::Errors.wrap(exception)
      expect(wrapped.code).to eq "validation_failed"
      expect(wrapped.details.join).to include('must satisfy ^\d+$')
    end
  end

  describe "create_analysis" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0, analyzers_count: 0)
      @ps = @sim.parameter_sets.first
      @run = FactoryBot.create(:finished_run, parameter_set: @ps)
      @azr = FactoryBot.create(:analyzer, simulator: @sim, type: :on_run, run_analysis: false)
      @host = @azr.executable_on.first
    end

    it "creates an analysis on a finished run with default parameters" do
      result = registry.call("create_analysis", {"analyzer" => @azr.name, "run_id" => @run.id.to_s, "host" => @host.name})
      expect(result["created"]).to be true
      expect(result["status"]).to eq "created"
      expect(result["parameters"]).to eq({"param1" => 50, "param2" => 1.0})
      expect(result["analyzable_type"]).to eq "Run"
    end

    it "is idempotent for the same analyzer and parameters" do
      first = registry.call("create_analysis", {"analyzer" => @azr.name, "run_id" => @run.id.to_s, "host" => @host.name})
      second = registry.call("create_analysis", {"analyzer" => @azr.name, "run_id" => @run.id.to_s, "host" => @host.name})
      expect(second["created"]).to be false
      expect(second["id"]).to eq first["id"]
      third = registry.call("create_analysis", {"analyzer" => @azr.name, "run_id" => @run.id.to_s,
                                                "host" => @host.name, "parameters" => {"param1" => 99}})
      expect(third["created"]).to be true
    end

    it "rejects a run target for an on_parameter_set analyzer" do
      azr_ps = FactoryBot.create(:analyzer, simulator: @sim, type: :on_parameter_set, run_analysis: false)
      expect {
        registry.call("create_analysis", {"analyzer" => azr_ps.name, "run_id" => @run.id.to_s, "host" => @host.name})
      }.to raise_error(McpServer::ToolError) {|e|
        expect(e.code).to eq "invalid_arguments"
        expect(e.message).to match(/parameter_set_id/)
      }
    end

    it "creates an analysis on a parameter set with finished runs" do
      azr_ps = FactoryBot.create(:analyzer, simulator: @sim, type: :on_parameter_set, run_analysis: false)
      result = registry.call("create_analysis", {"analyzer" => azr_ps.name, "parameter_set_id" => @ps.id.to_s,
                                                 "host" => azr_ps.executable_on.first.name})
      expect(result["created"]).to be true
      expect(result["analyzable_type"]).to eq "ParameterSet"
    end

    it "rejects an unfinished run" do
      unfinished = FactoryBot.create(:run, parameter_set: @ps)
      expect {
        registry.call("create_analysis", {"analyzer" => @azr.name, "run_id" => unfinished.id.to_s, "host" => @host.name})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_state" }
    end

    it "rejects a parameter set with no finished runs" do
      azr_ps = FactoryBot.create(:analyzer, simulator: @sim, type: :on_parameter_set, run_analysis: false)
      empty_ps = FactoryBot.create(:parameter_set, simulator: @sim, runs_count: 0)
      expect {
        registry.call("create_analysis", {"analyzer" => azr_ps.name, "parameter_set_id" => empty_ps.id.to_s,
                                          "host" => azr_ps.executable_on.first.name})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_state" }
    end
  end
end
