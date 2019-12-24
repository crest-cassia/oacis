require 'spec_helper'

describe Simulator do

  before(:each) do
    @valid_fields = {
      name:"simulatorA",
      command: "~/path_to_a_simulator",
      parameter_definitions_attributes: [
        { key: "L", type: "Integer", default: "0" },
        { key: "T", type: "Float", default: "3.0" }
      ]
    }
  end

  describe "default_scope" do

    before(:each) do
      FactoryBot.create(:simulator, parameter_sets_count: 0, analyzers_count: 0)
    end

    it "ignores Simulator of to_be_destroyed=true by default" do
      sim = Simulator.first
      expect {
        sim.update_attribute(:to_be_destroyed, true)
      }.to change { Simulator.count }.by(-1)
      expect( Simulator.all.to_a ).to_not include(sim)
    end
  end

  it "should be valid with appropriate fields" do
    expect(Simulator.new(@valid_fields)).to be_valid
  end

  describe "'name' field" do

    it "must exist" do
      expect(Simulator.new(@valid_fields.update(name:""))).not_to be_valid
    end

    it "must be unique" do
      Simulator.create!(@valid_fields)
      expect(Simulator.new(@valid_fields)).not_to be_valid
    end

    it "must be organized with word characters" do
      expect(Simulator.new(@valid_fields.update({name:"b l a n k"}))).not_to be_valid
    end

    it "is editable after a parameter set is created" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      sim.name = "AnotherSimulator"
      expect(sim).to be_valid
    end

    it "is valid when name is identical to a simulator being destroyed" do
      sim = Simulator.create!(@valid_fields)
      sim.update_attribute(:to_be_destroyed, true)
      expect( Simulator.new(@valid_fields) ).to be_valid
    end

    it "can take identical name for simulators being destroyed" do
      attr = @valid_fields.update(to_be_destroyed: true)
      Simulator.create!(attr)
      expect( Simulator.new(attr) ).to be_valid
    end
  end

  describe "'command' field" do

    it "must exist" do
      invalid_attr = @valid_fields
      invalid_attr.delete(:command)
      expect(Simulator.new(invalid_attr)).not_to be_valid
    end
  end

  describe "parameter_sets" do

    before(:each) do
      @simulator = Simulator.create!(@valid_fields)
    end

    it "should have 'parameter_sets' method" do
      expect(@simulator).to respond_to(:parameter_sets)
    end

    it "should return 'parameter_sets'" do
      expect(@simulator.parameter_sets).to eq([])

      param_attribute = {:v => {"L" => 32, "T" => 0.1} }
      @simulator.parameter_sets.create!(param_attribute)
      @simulator.parameter_sets.count == 1
    end
  end

  describe "result directory" do

    before(:each) do
      @root_dir = ResultDirectory.root
      FileUtils.rm_r(@root_dir) if FileTest.directory?(@root_dir)
      FileUtils.mkdir(@root_dir)
    end

    after(:each) do
      FileUtils.rm_r(@root_dir) if FileTest.directory?(@root_dir)
    end

    it "is created when a new item is added" do
      sim = Simulator.create!(@valid_fields)
      expect(FileTest.directory?(ResultDirectory.simulator_path(sim))).to be_truthy
    end

    it "is not created when validation fails" do
      Simulator.create(@valid_fields.update(name:""))
      expect(Dir.entries(ResultDirectory.root) - ['.', '..']).to be_empty
    end
  end

  describe "'description' field" do

    it "responds to 'description'" do
      expect(Simulator.new).to respond_to(:description)
    end
  end

  describe "'position' field" do

    before(:each) do
      FactoryBot.create_list(:simulator, 2)
    end

    it "the largest number within existing simulators is assigned when created" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 0, analyzers_count: 0)
      expect(sim.position).to eq 2
      expect(Simulator.all.map(&:position)).to match_array([0,1,2])
    end
  end

  describe ".find_by_name" do

    it "returns the simulator with the given name" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 0)
      found = Simulator.find_by_name(sim.name)
      expect(sim).to eq found
    end

    it "raises an exception when the simulator is not found" do
      expect {
        Simulator.find_by_name("do_not_exist")
      }.to raise_error("Simulator do_not_exist is not found")
    end
  end

  describe "#find_parameter_set" do

    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 0)
    end

    it "returns PS with the given parameters" do
      parameters = {"L"=>10, "T"=>2.0}
      created = @sim.parameter_sets.create!(v: parameters)
      found = @sim.find_parameter_set( parameters )
      expect(found).to eq created
    end

    it "returns PS irrespective of the order of the parameters" do
      created = @sim.parameter_sets.create!(v: {"L"=>10,"T"=>2.0} )
      found = @sim.find_parameter_set( "T"=>2.0, "L"=>10 )
      expect(found).to eq created
    end

    it "returns nil if matching PS is not found" do
      parameters = {"L"=>10, "T"=>2.0}
      @sim.parameter_sets.create!(v: parameters)
      found = @sim.find_parameter_set( {"L"=>20, "T"=>1.0} )
      expect(found).to be_nil
    end

    it "arguments can be a hash with symbol-keys" do
      parameters = {"L"=>10, "T"=>2.0}
      created = @sim.parameter_sets.create!(v: parameters)
      found = @sim.find_parameter_set( L:10, T:2.0 )
      expect(found).to eq created
    end

    it "raises an exception when unknown key is included in the argument" do
      parameters = {"L"=>10, "T"=>2.0}
      @sim.parameter_sets.create!(v: parameters)
      expect {
        @sim.find_parameter_set( parameters.merge({"Q"=>1}) )
      }.to raise_error(/^Unknown keys:/)
    end

    it "raises an exception when the given parameter has a missing key" do
      expect {
        @sim.find_parameter_set( "L" => 10 )
      }.to raise_error(/^Missing keys:/)
    end
  end

  describe "#find_or_create_parameter_set" do

    before(:each) do
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 0)
    end

    it "returns PS if there exists a PS with given parameters" do
      parameters = {"L"=>10, "T"=>2.0}
      created = @sim.parameter_sets.create!(v: parameters)
      found = @sim.find_or_create_parameter_set( parameters )
      expect(found).to eq created
    end

    it "creates a new PS with given parameters if no matching PS exists" do
      parameters = {"L"=>10, "T"=>2.0}
      expect {
        found = @sim.find_or_create_parameter_set( parameters )
        expect(found.v).to eq parameters
      }.to change { ParameterSet.count }.by(1)
    end

    it "arguments can be a hash with symbol-keys" do
      created = @sim.find_or_create_parameter_set( L:10, T:2.0 )
      expect(created.v).to eq({"L"=>10,"T"=>2.0})
    end

    it "raises an exception when unknown key is included in the argument" do
      parameters = {"L"=>10, "T"=>2.0}
      expect {
        @sim.find_or_create_parameter_set( parameters.merge({"Q"=>1}) )
      }.to raise_error(/^Unknown keys:/)
    end

    it "raises an exception when the given parameter has a missing key" do
      expect {
      @sim.find_or_create_parameter_set( {"L"=>10} )
      }.to raise_error(/^Missing keys:/)
    end
  end

  describe "#default_parameters" do

    it "returns default parameters" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 0)
      expected = {"L" => 50, "T" => 1.0}
      expect( sim.default_parameters ).to eq expected
    end

    it "returns hash which is accessible also with symbol" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 0)
      expect( sim.default_parameters[:L] ).to_not be_nil
      expect( sim.default_parameters[:T] ).to_not be_nil
    end
  end

  describe "#find_analyzer_by_name" do

    it "returns the analyzer of the given name" do
      sim = FactoryBot.create(:simulator, analyzers_count: 2)
      azr = sim.analyzers.first
      found = sim.find_analyzer_by_name( azr.name )
      expect(found).to eq azr
    end

    it "raises an exception when the analyzer is not found" do
      sim = FactoryBot.create(:simulator, analyzers_count: 0)
      expect {
        azr = sim.find_analyzer_by_name("do_not_exist")
      }.to raise_error("Analyzer do_not_exist is not found")
    end
  end

  describe "#discard" do

    before(:each) do
      @sim = FactoryBot.create(:simulator)
    end

    it "updates 'to_be_destroyed' to true" do
      expect {
        @sim.discard
      }.to change { @sim.to_be_destroyed }.from(false).to(true)
    end

    it "should receive 'set_lower_submittable_to_be_destroyed'" do
      expect(@sim).to receive(:set_lower_submittable_to_be_destroyed)
      @sim.discard
    end
  end

  describe "#set_lower_submittable_to_be_destroyed" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1, run_analysis: true,
                                analyzers_on_parameter_set_count: 1,
                                run_analysis_on_parameter_set: true
                                )
    end

    it "sets to_be_destroyed of lower Runs" do
      expect {
        @sim.set_lower_submittable_to_be_destroyed
      }.to change { @sim.reload.runs.empty? }.from(false).to(true)
    end

    it "sets to_be_destroyed of lower run-Analysis" do
      run = @sim.reload.runs.first
      expect {
        @sim.set_lower_submittable_to_be_destroyed
      }.to change { run.reload.analyses.empty? }.from(false).to(true)
    end

    it "sets to_be_destroyed of lower ps-Analysis" do
      ps = @sim.parameter_sets.first
      expect {
        @sim.set_lower_submittable_to_be_destroyed
      }.to change { ps.reload.analyses.empty? }.from(false).to(true)
    end
  end

  describe "#destroyable?" do
    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1, run_analysis: true,
                                analyzers_on_parameter_set_count: 1,
                                run_analysis_on_parameter_set: true
                                )
    end

    it "returns false when it has Run or Analysis" do
      expect(@sim.destroyable?).to be_falsey
    end

    it "returns true when all the Run or Analysis is destroyed" do
      @sim.set_lower_submittable_to_be_destroyed
      expect( @sim.destroyable? ).to be_falsey
      @sim.runs.unscoped.first.analyses.unscoped.destroy
      expect( @sim.destroyable? ).to be_falsey
      @sim.runs.unscoped.destroy
      expect( @sim.destroyable? ).to be_falsey
      @sim.parameter_sets.first.analyses.unscoped.destroy
      expect( @sim.destroyable? ).to be_truthy
    end
  end

  describe "#destroy" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1
                                )
    end

    it "calls destroy of dependent parameter_sets when destroyed" do
      expect {
        @sim.destroy
      }.to change { ParameterSet.count }.by(-1)
    end

    it "does not call destroy of dependent runs when destroyed" do
      expect {
        @sim.destroy
      }.to_not change { Run.unscoped.count }
    end

    it "calls destroy of dependent analyzer when destroyed" do
      expect {
        @sim.destroy
      }.to change { Analyzer.count }.by(-1)
    end

    it "deletes result_directory" do
      dir_path = @sim.dir
      expect {
        @sim.destroy
      }.to change { File.directory?(dir_path) }.from(true).to(false)
    end
  end

  describe "#dir" do

    it "returns the result directory of the simulator" do
      sim = FactoryBot.create(:simulator,
                              parameter_sets_count: 0,
                              runs_count: 0)
      expect(sim.dir).to eq(ResultDirectory.simulator_path(sim))
    end
  end

  describe "#analyzers_on_run" do

    it "returns analyzers whose type is :on_run" do
      sim = FactoryBot.create(:simulator, 
                               parameter_sets_count: 0,
                               runs_count: 0,
                               analyzers_count: 0,
                               parameter_set_filters_count:0
                               )
      FactoryBot.create_list(:analyzer, 5,
                              type: :on_run,
                              simulator: sim)
      FactoryBot.create_list(:analyzer, 5,
                              type: :on_parameter_set,
                              simulator: sim)

      expect(sim.analyzers_on_run).to be_a(Mongoid::Criteria)
      expect(sim.analyzers_on_run).to eq(sim.analyzers.where(type: :on_run))
      expect(sim.analyzers_on_run.count).to eq(5)
    end
  end

  describe "#analyzers_on_parameter_set" do

    it "returns analyzers whose type is :on_parameter_set" do
      sim = FactoryBot.create(:simulator,
                               parameter_sets_count: 0,
                               runs_count: 0,
                               analyzers_count: 0,
                               parameter_set_filters_count:0
                               )
      FactoryBot.create_list(:analyzer, 1,
                              type: :on_run,
                              simulator: sim)
      FactoryBot.create_list(:analyzer, 2,
                              type: :on_parameter_set,
                              simulator: sim)

      expect(sim.analyzers_on_parameter_set).to be_a(Mongoid::Criteria)
      expect(sim.analyzers_on_parameter_set).to eq(sim.analyzers.where(type: :on_parameter_set))
      expect(sim.analyzers_on_parameter_set.count).to eq(2)
    end
  end

  describe "#plottable" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 1,
                               analyzers_count: 1,
                               run_analysis: true)
      run = @sim.parameter_sets.first.runs.first
      run.status = :finished
      run.result = { r1: 1, r2: { r3: 3, r4: 4}, r5: [1,2,3] }
      run.save!

      anl = @sim.analyzers.first.analyses.first
      anl.status = :finished
      anl.result = { a1: 1, a2: { a3: 3, a4: 4}, a5: [1,2,3] }
      anl.save!
    end

    it "return array of plottable keys" do
      analyzer_name = @sim.analyzers.first.name
      expect(@sim.plottable).to eq [
        "cpu_time", "real_time",
        ".r1", ".r2.r3", ".r2.r4",
        "#{analyzer_name}.a1", "#{analyzer_name}.a2.a3", "#{analyzer_name}.a2.a4"
      ]
    end
  end

  describe "#plottable_domains" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 2,
                               analyzers_count: 1,
                               run_analysis: true)
      runs = @sim.parameter_sets.first.runs.asc(:_id)
      runs.each_with_index do |run, idx|
        run.status = :finished
        run.result = { r1: 1+idx, r2: { r3: 3+idx, r4: 4+idx}, r5: [1,2,3] }
        run.cpu_time = 10.0 + idx
        run.real_time = 3.0 + idx
        run.save!
      end

      @sim.analyzers.first.analyses.each_with_index do |anl, idx|
        anl.status = :finished
        anl.result = { a1: 1+idx, a2: { a3: 3+idx, a4: 4+idx}, a5: [1,2,3] }
        anl.save!
      end
    end

    it "return the min and max values for each result" do
      azr = @sim.analyzers.first
      expected = {
        "cpu_time" => [0.0, 11.0],
        "real_time" => [0.0, 4.0],
        ".r1" => [1, 2],
        ".r2.r3" => [3, 4],
        ".r2.r4" => [4, 5],
        "#{azr.name}.a1" => [1, 2],
        "#{azr.name}.a2.a3" => [3, 4],
        "#{azr.name}.a2.a4" => [4, 5]
      }
      expect(@sim.plottable_domains).to eq expected
    end
  end

  describe "#parameter_ranges" do

    before(:each) do
      parameter_definitions = [
        ParameterDefinition.new({ key: "L", type: "Integer", default: 0}),
        ParameterDefinition.new({ key: "T", type: "Float", default: 1.0}),
        ParameterDefinition.new({ key: "S", type: "String", default: 'xxx'})
      ]
      @sim = FactoryBot.create(:simulator,
                                parameter_definitions: parameter_definitions,
                                parameter_sets_count: 0)
      create_ps = lambda {|h| FactoryBot.create(:parameter_set, {simulator: @sim}.merge(h)) }
      create_ps.call(v: {"L" => 1, "T" => 1.0})
      create_ps.call(v: {"L" => 2, "T" => 1.0})
      create_ps.call(v: {"L" => 3, "T" => 1.0})
      create_ps.call(v: {"L" => 1, "T" => 10.0})
    end

    it "returns ranges of each parameters" do
      expected = {
        "L" => [1, 3],
        "T" => [1.0, 10.0],
        "S" => [nil, nil]
      }
      expect(@sim.parameter_ranges).to eq expected
    end
  end

  describe "#progress_overview_data" do

    before(:each) do
      parameter_definitions = [
        ParameterDefinition.new({ key: "L", type: "Integer", default: 0}),
        ParameterDefinition.new({ key: "T", type: "Float", default: 1.0}),
        ParameterDefinition.new({ key: "S", type: "String", default: "xxx"})
      ]
      @sim = FactoryBot.create(:simulator,
                                parameter_definitions: parameter_definitions,
                                parameter_sets_count: 0)
      create_ps = lambda {|h| FactoryBot.create(:parameter_set, {simulator: @sim}.merge(h)) }
      create_ps.call( v: {"L" => 1, "T" => 1.0}, runs_count: 2, finished_runs_count: 3)
      create_ps.call( v: {"L" => 2, "T" => 1.0}, runs_count: 2, finished_runs_count: 3)
      create_ps.call( v: {"L" => 3, "T" => 1.0}, runs_count: 2, finished_runs_count: 3)
      create_ps.call( v: {"L" => 1, "T" => 2.0}, runs_count: 2, finished_runs_count: 3)
      create_ps.call( v: {"L" => 2, "T" => 2.0}, runs_count: 0, finished_runs_count: 8)
      create_ps.call( v: {"L" => 1, "T" => 1.0, "S" => "yyy"}, runs_count: 1, finished_runs_count: 2)
    end

    it "returns a Hash with valid keys" do
      progress = @sim.progress_overview_data("L", "T")
      expect(progress).to be_a(Hash)
      expect(progress.keys).to match_array([:parameters, :parameter_values, :num_runs])
    end

    it "progress[:parameters] is an Array of row_parameter and column_parameter" do
      expect(@sim.progress_overview_data("L", "T")[:parameters]).to eq ["L", "T"]
    end

    it "progress[:parameter_values] are distinct values for each parameters" do
      param_values = @sim.progress_overview_data("L", "T")[:parameter_values]
      param_values[0] = [1,2,3]    # <= @sim.parameter_sets.distinct("v.L").sort
      param_values[1] = [1.0, 2.0] # <= @sim.parameter_sets.distinct("v.T").sort
    end

    it "progress[:num_runs] is matrix having [finished_runs, total_runs]" do
      num_runs = @sim.progress_overview_data("L", "T")[:num_runs]
      expected = [
        # L=1,   2,     3
        [ [5,8], [3,5], [3,5] ], # T=1.0
        [ [3,5], [8,8], [0,0] ], # T=2.0
      ]
      expect(num_runs).to eq expected
    end

    context "when first and second parameters are same" do

      it "progress[:num_runs] should have only diaglonal elements" do
        num_runs = @sim.progress_overview_data("L", "L")[:num_runs]
        expected = [
          # L=1,   2,      3
          [ [8,13],[0,0],  [0,0] ], # L=1
          [ [0,0], [11,13],[0,0] ], # L=2
          [ [0,0], [0,0],  [3,5] ], # L=3
        ]
        expect(num_runs).to eq expected
      end
    end
  end

  describe "#simulator_versions" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1, runs_count: 1, finished_runs_count: 5)
      runs = @sim.runs.in(status: [:finished, :failed]).asc(:id)

      runs[0].update_attribute(:started_at, 3.days.ago)
      runs[0].update_attribute(:simulator_version, "v1")
      runs[1].update_attribute(:started_at, 2.days.ago)
      runs[1].update_attribute(:simulator_version, "v1")
      runs[2].update_attribute(:started_at, 3.days.ago)
      runs[2].update_attribute(:simulator_version, "v2")
      runs[3].update_attribute(:started_at, 2.days.ago)
      runs[3].update_attribute(:simulator_version, "v2")
      runs[4].update_attribute(:started_at, 1.days.ago)
      runs[4].update_attribute(:simulator_version, "v2")
      runs[4].update_attribute(:status, :failed)
    end

    it "returns list of simulator_versions in Array" do
      expect(@sim.simulator_versions).to be_a(Array)
    end

    it "returns array of hash whose 'version' field is simulator_versions" do
      expect(@sim.simulator_versions.map {|h| h['version']}).to match_array(["v1", "v2"])
    end

    it "returns array of hash which has 'oldest_started_at' and 'latest_started_at' fields" do
      runs = @sim.runs.in(status: [:finished, :failed]).asc(:id)
      expected = [
        { "version" => "v1",
          "oldest_started_at" => runs[0].started_at,
          "latest_started_at" => runs[1].started_at,
          "count" => {finished: 2} },
        { "version" => "v2",
          "oldest_started_at" => runs[2].started_at,
          "latest_started_at" => runs[4].started_at,
          "count" => {finished: 2, failed: 1} }
      ]
      expect(@sim.simulator_versions).to match_array(expected)
    end

    it "returns array which is sorted by 'latest_started_at' in ascending order" do
      expect(@sim.simulator_versions.map {|h| h['version']}).to eq ["v1", "v2"]
    end

    it "counts runs for each status" do
      finished_count = @sim.runs.where(status: :finished).count
      failed_count = @sim.runs.where(status: :failed).count
      output = @sim.simulator_versions
      expect(output.map {|h| h['count'][:finished].to_i }.inject(:+)).to eq finished_count
      expect(output.map {|h| h['count'][:failed].to_i }.inject(:+)).to eq failed_count
    end
  end

  describe "#figure_files" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1,
                                run_analysis: true)
      run = @sim.parameter_sets.first.runs.first
      run.update_attribute(:status, :finished)
      @figure_extensions = ["png","Jpg","JPEG","bmp","SVG"]
      @figure_extensions.each do |fe|
        FileUtils.touch(run.dir.join("fig1."+fe))
      end
      FileUtils.touch(run.dir.join("dummy.txt"))

      anl = @sim.analyzers.first.analyses.first
      anl.update_attribute(:status, :finished)
      FileUtils.touch(anl.dir.join("fig2.jpg"))
    end

    it "return array of PNG, JPG, BMP, SVG filenames in the result directory" do
      analyzer_name = @sim.analyzers.first.name
      expected_files = @figure_extensions.map {|fe| "/fig1."+fe}
      expected_files += ["#{analyzer_name}/fig2.jpg"]
      expect(@sim.figure_files).to match_array(expected_files)
    end

    context "when there is no finished run or analysis" do

      it "does not include the result for a failed run" do
        @sim.runs.first.update_attribute(:status, :failed)
        expect(@sim.figure_files.any? {|f| f =~ /fig1/ }).to be_falsey
      end

      it "does not include the result for a failed analysis" do
        @sim.analyzers.first.analyses.first.update_attribute(:status, :failed)
        expect(@sim.figure_files.any? {|f| f =~ /fig2/ }).to be_falsey
      end
    end
  end

  describe "get_default_host_parameter" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 0
                               )
      @host = FactoryBot.create(:host_with_parameters)
      @sim.executable_on.destroy
      @sim.executable_on << @host
    end

    context "when there is no run" do

      it "return default_host_parameter associated with a host" do
        key_value = @sim.executable_on.first.host_parameter_definitions.map {|pd| [pd.key, pd.default]}
        expect(@sim.get_default_host_parameter(@sim.executable_on.first)).to eq Hash[*key_value.flatten]
      end
    end

    context "when new run is created" do

      it "return the host parameters of the last created run" do
        host_parameters = @sim.get_default_host_parameter(@sim.executable_on.first) # {"param1"=>nil, "param2"=>"XXX"}
        run = @sim.parameter_sets.first.runs.build({submitted_to: @sim.executable_on.first, host_parameters: host_parameters})
        expect {
          run.host_parameters["param2"] = "YYY"
          run.save
        }.to change { @sim.reload.get_default_host_parameter(@sim.executable_on.first)["param2"] }.from("XXX").to("YYY")
      end
    end
  end

  describe "#runs_csv" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                               parameter_sets_count: 2,
                               runs_count: 2,
                               analyzers_count: 0)
      runs = @sim.parameter_sets.first.runs.asc(:_id)
      runs.each_with_index do |run, idx|
        run.status = :finished
        run.result = { r1: 1+idx, r2: { r3: 3+idx, r4: 4+idx} }
        run.cpu_time = 10.0 + idx
        run.real_time = 3.0 + idx
        run.started_at = Time.zone.now
        run.finished_at = Time.zone.now
        run.hostname = "localhost"
        run.save!
      end
    end

    it "returns runs in CSV format" do
      csv = @sim.runs_csv.lines
      expected_header = <<~EOS
        run_id,status,hostname,real_time,started_at,finished_at,seed,ps_id,p.L,p.T,r.r1,r.r2.r3,r.r2.r4
      EOS
      id_format = /\A[0-9a-f]{24}\z/
      status_format = /\Acreated|finished\z/
      int_format = /\A\d+\z/
      float_format = /\A\d+[.]?\d*\z/
      date_format = /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [A-Z]{3}\z/
      expect(csv[0]).to eq expected_header
      csv[1..-1].each do |row|
        a = row.chomp.split(',')
        expect(a[0]).to match(id_format)
        expect(a[1]).to match(status_format)
        expect(a[2]).to eq("localhost").or eq("")
        expect(a[3]).to match(float_format).or eq("")
        expect(a[4]).to match(date_format).or eq("") # started_at
        expect(a[5]).to match(date_format).or eq("") # finished_at
        expect(a[6]).to match(/\A\d+\z/)             # seed
        expect(a[7]).to match(id_format)             # ps_id
        expect(a[8]).to match(int_format)            # p.L
        expect(a[9]).to match(float_format)          # p.T
        a[10..-1].each do |x|               # result
          expect(x).to match(int_format).or eq("")
        end
      end
    end
  end
end
