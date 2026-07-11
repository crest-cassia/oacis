require 'spec_helper'
require Rails.root.join('lib/mcp_server/server')

describe "McpServer read tools" do

  let(:registry) { McpServer::Server.build_registry(access_level: 2, read_only: false) }

  describe "list_simulators" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 2, analyzers_count: 1, run_analysis: false)
    end

    it "returns simulators with parameter definitions, analyzers, and run status counts" do
      result = registry.call("list_simulators", {})
      expect(result["total"]).to eq 1
      sim = result["simulators"].first
      expect(sim["name"]).to eq @sim.name
      expect(sim["parameter_definitions"].map {|pd| pd["key"] }).to eq ["L", "T"]
      expect(sim["parameter_definitions"].first).to include("type" => "Integer", "default" => 50)
      expect(sim["analyzers"].size).to eq 1
      expect(sim["executable_on"]).to be_present
      expect(sim["runs_status_count"]).to include("created" => 2, "finished" => 0)
    end

    it "filters by name_contains" do
      result = registry.call("list_simulators", {"name_contains" => "no_such_simulator"})
      expect(result["total"]).to eq 0
    end
  end

  describe "list_hosts" do
    before(:each) do
      @host = FactoryBot.create(:host_with_parameters)
      @host_group = FactoryBot.create(:host_group)
    end

    it "returns hosts with host parameter definitions and host groups" do
      result = registry.call("list_hosts", {})
      host = result["hosts"].detect {|h| h["name"] == @host.name }
      expect(host["host_parameter_definitions"].map {|d| d["key"] }).to eq ["param1", "param2"]
      expect(host["default_host_parameters"]).to eq({"param1" => nil, "param2" => "XXX"})
      expect(host).to include("min_mpi_procs", "max_mpi_procs", "max_num_jobs")
      hg = result["host_groups"].detect {|h| h["name"] == @host_group.name }
      expect(hg["hosts"]).to eq @host_group.hosts.map(&:name)
    end
  end

  describe "search_parameter_sets" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 3, runs_count: 1, analyzers_count: 0)
    end

    it "returns all parameter sets of the simulator with run counts" do
      result = registry.call("search_parameter_sets", {"simulator" => @sim.name})
      expect(result["total"]).to eq 3
      ps = result["parameter_sets"].first
      expect(ps["v"]).to be_a Hash
      expect(ps["run_counts"]).to include("created" => 1)
    end

    it "filters by a subset of parameter values, casting types" do
      target = @sim.parameter_sets.first
      result = registry.call("search_parameter_sets",
                             {"simulator" => @sim.name, "v" => {"L" => target.v["L"].to_s}})
      expect(result["total"]).to eq 1
      expect(result["parameter_sets"].first["id"]).to eq target.id.to_s
    end

    it "paginates" do
      result = registry.call("search_parameter_sets", {"simulator" => @sim.name, "limit" => 2, "offset" => 2})
      expect(result["total"]).to eq 3
      expect(result["parameter_sets"].size).to eq 1
    end

    it "rejects unknown parameter keys" do
      expect {
        registry.call("search_parameter_sets", {"simulator" => @sim.name, "v" => {"bogus" => 1}})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_parameters" }
    end

    it "raises not_found for an unknown simulator" do
      expect {
        registry.call("search_parameter_sets", {"simulator" => "no_such_sim"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "not_found" }
    end
  end

  describe "get_parameter_set" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1, analyzers_count: 0)
      @ps = @sim.parameter_sets.first
      FactoryBot.create_list(:finished_run, 2, parameter_set: @ps)
    end

    it "returns the parameter set with run counts and a run preview" do
      result = registry.call("get_parameter_set", {"parameter_set_id" => @ps.id.to_s})
      expect(result["id"]).to eq @ps.id.to_s
      expect(result["run_counts"]).to include("created" => 1, "finished" => 2)
      expect(result["runs"].size).to eq 3
      expect(result["runs"].first).to include("id", "status")
    end

    it "omits runs when include_runs is false" do
      result = registry.call("get_parameter_set", {"parameter_set_id" => @ps.id.to_s, "include_runs" => false})
      expect(result).not_to have_key("runs")
    end

    it "computes average results over finished runs when requested" do
      result = registry.call("get_parameter_set",
                             {"parameter_set_id" => @ps.id.to_s, "include_average_results" => true})
      expect(result["average_results"].keys).to match_array ["Energy", "Flow"]
      expect(result["average_results"]["Energy"]["count"]).to eq 2
      expect(result["average_results"]["Energy"]["average"]).to be_a Float
    end
  end

  describe "get_run" do
    before(:each) do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0, analyzers_count: 0)
      @ps = sim.parameter_sets.first
      @run = FactoryBot.create(:finished_run, parameter_set: @ps)
    end

    it "returns the full run including result and parameters" do
      result = registry.call("get_run", {"run_id" => @run.id.to_s})
      expect(result).to include(
        "id" => @run.id.to_s,
        "status" => "finished",
        "parameter_set_id" => @ps.id.to_s
      )
      expect(result["result"].keys).to match_array ["Energy", "Flow"]
      expect(result["v"]).to eq @ps.v
      expect(result["submitted_to"]).to eq @run.submitted_to.name
    end

    it "raises not_found for a nonexistent id" do
      expect {
        registry.call("get_run", {"run_id" => "0" * 24})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "not_found" }
    end

    it "rejects a malformed id" do
      expect {
        registry.call("get_run", {"run_id" => "not-an-id"})
      }.to raise_error(McpServer::ToolError) {|e| expect(e.code).to eq "invalid_arguments" }
    end
  end

  describe "list_runs" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 2, runs_count: 2, analyzers_count: 0)
      @ps = @sim.parameter_sets.first
      FactoryBot.create(:finished_run, parameter_set: @ps)
    end

    it "lists runs of a parameter set" do
      result = registry.call("list_runs", {"parameter_set_id" => @ps.id.to_s})
      expect(result["total"]).to eq 3
    end

    it "filters by status" do
      result = registry.call("list_runs", {"parameter_set_id" => @ps.id.to_s, "status" => "finished"})
      expect(result["total"]).to eq 1
      expect(result["runs"].first["status"]).to eq "finished"
    end

    it "lists runs across a whole simulator" do
      result = registry.call("list_runs", {"simulator" => @sim.name})
      expect(result["total"]).to eq 5
    end

    it "requires exactly one scope" do
      expect {
        registry.call("list_runs", {})
      }.to raise_error(McpServer::InvalidArgumentsError)
      expect {
        registry.call("list_runs", {"simulator" => @sim.name, "parameter_set_id" => @ps.id.to_s})
      }.to raise_error(McpServer::InvalidArgumentsError)
    end
  end

  describe "get_analysis / list_analyses" do
    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1, analyzers_count: 1, run_analysis: true)
      @ps = @sim.parameter_sets.first
      @run = @ps.runs.first
      @analysis = @run.analyses.first
    end

    it "gets one analysis with its target and result" do
      result = registry.call("get_analysis", {"analysis_id" => @analysis.id.to_s})
      expect(result).to include(
        "id" => @analysis.id.to_s,
        "analyzable_type" => "Run",
        "analyzable_id" => @run.id.to_s,
        "analyzer" => @analysis.analyzer.name
      )
      expect(result["result"]).to be_a Hash
    end

    it "lists analyses on a run" do
      result = registry.call("list_analyses", {"run_id" => @run.id.to_s})
      expect(result["total"]).to eq 1
    end

    it "lists analyses under a parameter set" do
      result = registry.call("list_analyses", {"parameter_set_id" => @ps.id.to_s})
      expect(result["total"]).to eq 1
    end

    it "lists analyses of a simulator filtered by analyzer" do
      azr = @analysis.analyzer
      result = registry.call("list_analyses", {"simulator" => @sim.name, "analyzer" => azr.name})
      expect(result["total"]).to eq 1
      result = registry.call("list_analyses", {"simulator" => @sim.name, "analyzer" => azr.name, "status" => "created"})
      expect(result["total"]).to eq 0
    end
  end
end
