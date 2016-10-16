require 'spec_helper'

describe ParameterSet do

  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1,
                              runs_count: 1
                              )
    @valid_attr = {:v => {"L" => 32, "T" => 1.0}}
  end

  describe "default_scope" do

    it "ignores ParameterSet of to_be_destroyed=true by default" do
      ps = ParameterSet.first
      expect {
        ps.update_attribute(:to_be_destroyed, true)
      }.to change { ParameterSet.count }.by(-1)
      expect( ParameterSet.all.to_a ).to_not include(ps)
    end
  end

  describe "validation" do

    it "should create a ParameterSet when valid attributes are given" do
      expect {
        @sim.parameter_sets.create!(@valid_attr)
      }.not_to raise_error
    end

    it "should not be valid when simulator is not related" do
      param = ParameterSet.new(@valid_attr)
      expect(param).not_to be_valid
    end

    it "should not be valid when v does not exist" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:v)
      built_param = @sim.parameter_sets.build(invalid_attr)
      expect(built_param).not_to be_valid
    end

    it "should raise an error when v is not a Hash" do
      invalid_attr = @valid_attr.update({v: "xxx"})
      expect {
        @sim.parameter_sets.build(invalid_attr)
      }.to raise_error
    end

    it "should not be valid when keys of v are not consistent with its Simulator" do
      pd = @sim.parameter_definitions.first
      pd.default = nil
      built_param = @sim.parameter_sets.build(@valid_attr.update({:v => {}}))
      expect(built_param).not_to be_valid
    end

    it "should not be valid when v contains an unknown key" do
      invalid_attr = @valid_attr.update(v: {"l" => 32, "T" => 1.0} )  # key "l" does not exist in parameter_definitions
      built = @sim.parameter_sets.build( invalid_attr )
      expect( built ).to_not be_valid
    end

    it "should not be valid when v is not unique" do
      @sim.parameter_sets.create!(@valid_attr)
      built = @sim.parameter_sets.build(@valid_attr)
      expect(built).not_to be_valid
      err = built.errors.messages
      expect(err).to have_key(:parameters)
      expect(err[:parameters].find {|x|
        x =~ /identical/
      }).to be_truthy
    end

    it "identical v is valid for a differnet simulator" do
      @sim.parameter_sets.create!(@valid_attr)

      sim2 = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0)
      built_param = sim2.parameter_sets.build(@valid_attr)
      expect(built_param).to be_valid
    end

    it "should cast the values of v properly" do
      updated_attr = @valid_attr.update(:v => {"L"=>"32","T"=>"2.0"})
      built = @sim.parameter_sets.build(updated_attr)
      expect(built).to be_valid
      expect(built[:v]["L"]).to eq(32)
      expect(built[:v]["T"]).to eq(2.0)
    end

    it "uses default values if a parameter value is not given" do
      updated_attr = @valid_attr.update(v: {})
      @sim.parameter_definition_for("L").default = 30
      @sim.parameter_definition_for("T").default = 2.0
      built = @sim.parameter_sets.build(updated_attr)
      expect(built).to be_valid
      expect(built[:v]["L"]).to eq(30)
      expect(built[:v]["T"]).to eq(2.0)
    end

    it "should be valid once it is saved with valid attributes" do
      prm = @sim.parameter_sets.first
      expect(prm).to be_valid
    end
  end

  describe "relations" do

    before(:each) do
      @ps = @sim.parameter_sets.first
    end

    it "has simulator method" do
      expect(@ps).to respond_to(:simulator)
    end

    it "has runs method" do
      expect(@ps).to respond_to(:runs)
    end

    it "does not call destroy of dependent runs when destroyed" do
      run = @ps.runs.first
      expect(run).to_not receive(:destroy)
      @ps.destroy
    end

    it "does not call destroy of dependent analyses when destroyed" do
      azr = FactoryGirl.create(:analyzer,
                               simulator: @sim,
                               type: :on_parameter_set
                               )
      anl = @ps.analyses.create(analyzable: @ps, analyzer: azr)
      expect(anl).to_not receive(:destroy)
      @ps.destroy
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
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 0)
      prm = sim.parameter_sets.create!(@valid_attr)
      expect(FileTest.directory?(ResultDirectory.parameter_set_path(prm))).to be_truthy
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 0)
      h = sim.parameter_definition_for("T")
      h.default = nil
      h.save!

      sim.parameter_sets.create(@valid_attr.update({:v => {"L"=>"abc"}}))
      expect(Dir.entries(ResultDirectory.simulator_path(sim)) - ['.','..']).to be_empty
    end
  end

  describe "#dir" do

    it "returns the result directory of the parameter" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      prm = sim.parameter_sets.first
      expect(prm.dir).to eq(ResultDirectory.parameter_set_path(prm))
    end
  end

  describe "#parameters_with_different" do

    before(:each) do
      pds = [
        ParameterDefinition.new(
          {key: "L", type: "Integer", default: 50, description: "First parameter"}),
        ParameterDefinition.new(
          {key: "T", type: "Float", default: 1.0, description: "Second parameter"}),
        ParameterDefinition.new(
          {key: "P", type: "Float", default: 1.0, description: "Third parameter"})
      ]
      sim = FactoryGirl.create(:simulator, parameter_definitions: pds, parameter_sets_count: 0)
      5.times do |n|
        val = {"L" => 1, "T" => (n+1)*1.0, "P" => 1.0}
        sim.parameter_sets.create( v: val )
      end
      4.times do |n|
        val = {"L" => 5-n, "T" => 1.0, "P" => 1.0}
        sim.parameter_sets.create( v: val )
      end
      4.times do |n|
        val = {"L" => 1, "T" => 1.0, "P" => (n+2)*1.0}
        sim.parameter_sets.create( v: val )
      end
      sim.parameter_sets.create(v: {"L" => 3, "T" => 1.0, "P" => 3.0})
      @prm = sim.parameter_sets.where('v.L'=>1,'v.T'=>1.0,'v.P'=>1.0).first
    end

    it "returns parameter_sets whose sim_parameter is same as self except for the specified key" do
      prms_L = @prm.parameter_sets_with_different("L")
      expect(prms_L.count).to eq(5)
      prms_L.each do |prm_L|
        expect(prm_L.v["T"]).to eq(@prm.v["T"])
      end

      prms_T = @prm.parameter_sets_with_different("T")
      expect(prms_T.count).to eq(5)
      prms_T.each do |prm_T|
        expect(prm_T.v["L"]).to eq(@prm.v["L"])
      end
    end

    it "includes self" do
      found = @prm.parameter_sets_with_different("L").find(@prm)
      expect(found).to be_a(ParameterSet)
    end

    it "returns parameter_sets sorted by the given key" do
      prms_L = @prm.parameter_sets_with_different("L")
      expect(prms_L.map {|x| x.v["L"]}).to eq [1,2,3,4,5]
    end

    context "when irrelevant keys are given" do

      it "ignores irrelevant keys when searching parameter sets" do
        prms_L = @prm.parameter_sets_with_different("L", ["P"])
        expect(prms_L.map {|x| x.v["L"]}).to eq [1,1,1,1,1,2,3,3,4,5]
      end
    end
  end

  describe "#parameter_keys_having_distinct_values" do

    before(:each) do
      pds = [
        ParameterDefinition.new(
          {key: "L", type: "Integer", default: 50, description: "First parameter"}),
        ParameterDefinition.new(
          {key: "T", type: "Float", default: 1.0, description: "Second parameter"}),
        ParameterDefinition.new(
          {key: "P", type: "Float", default: 1.0, description: "Third parameter"})
      ]
      sim = FactoryGirl.create(:simulator, parameter_definitions: pds, parameter_sets_count: 0)
      5.times do |n|
        val = {"L" => 1, "T" => (n+1)*1.0, "P" => 1.0}
        sim.parameter_sets.create( v: val )
      end
      4.times do |n|
        val = {"L" => 5-n, "T" => 1.0, "P" => 1.0}
        sim.parameter_sets.create( v: val )
      end
      @prm = sim.parameter_sets.where("v.L": 1, "v.T":1.0).first
    end

    it "returns array of parameter keys which have multiple distinct parameter values" do
      expect(@prm.parameter_keys_having_distinct_values).to eq ["L", "T"]
    end
  end

  describe "#runs_status_count" do

    def prepare_runs
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 10)
      prm = sim.parameter_sets.first
      prm.runs[0].update_attribute(:status, :submitted)
      (prm.runs[1..2]).each {|r| r.update_attribute(:status, :running) }
      (prm.runs[3..5]).each {|r| r.update_attribute(:status, :failed) }
      (prm.runs[6..9]).each {|r| r.update_attribute(:status, :finished) }
      prm
    end

    it "returns the runs count" do
      prm = prepare_runs
      expect(prm.runs_status_count.values.inject(:+)).to eq prm.runs.count
      expect(prm.runs_status_count[:created].to_i).to eq prm.runs.where(status: :created).count
      expect(prm.runs_status_count[:submitted].to_i).to eq prm.runs.where(status: :submitted).count
      expect(prm.runs_status_count[:running]).to eq prm.runs.where(status: :running).count
      expect(prm.runs_status_count[:finished]).to eq prm.runs.where(status: :finished).count
      expect(prm.runs_status_count[:failed]).to eq prm.runs.where(status: :failed).count
    end

    it "save the result into runs_status_count_cache field" do
      prm = prepare_runs
      expect(prm.runs_status_count_cache).to be_nil

      expect(Run).to receive(:collection).and_call_original
      prm.runs_status_count
      expect(prm.runs_status_count_cache).to be_a(Hash)
    end

    it "update progress_rate_cache field" do
      prm = prepare_runs
      expect(prm.runs_status_count_cache).to be_nil

      expect(Run).to receive(:collection).and_call_original
      prm.runs_status_count
      expect(prm.progress_rate_cache).to be_a(Integer)
    end
  end

  describe "#find_or_create_runs_upto" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      @ps = sim.parameter_sets.first
    end

    context "when the number of runs is smaller than the specified value" do 

      it "create the specified number of runs when no run exists" do
        expect {
          runs = @ps.find_or_create_runs_upto(3)
          expect( runs.count ).to eq 3
        }.to change { @ps.runs.count }.from(0).to(3)
      end

      it "creates runs upto specified number of runs" do
        run1 = @ps.runs.create!
        expect {
          runs = @ps.find_or_create_runs_upto(3)
          expect( runs.count ).to eq 3
          expect( runs.include?(run1) ).to be_truthy
        }.to change { @ps.runs.count }.from(1).to(3)
      end

      it "sets submitted_to, host_param, mpi_proc, omp_threads to newly created runs" do
        h = FactoryGirl.create(:host_with_parameters)
        host_param = { param1: "foo", param2: "bar" }
        mpi_procs = 1
        omp_threads = 4
        
        runs = @ps.find_or_create_runs_upto(3,
                                            submitted_to: h,
                                            host_param: host_param,
                                            mpi_procs: 1,
                                            omp_threads: 4 )
        expect( runs.count ).to eq 3
        runs.each do |run|
          expect( run.submitted_to ).to eq h
          expect( run.host_parameters ).to eq({"param1"=>"foo","param2"=>"bar"})
          expect( run.mpi_procs ).to eq 1
          expect( run.omp_threads ).to eq 4
        end
      end

      it "does not set host_param to existing runs" do
        run1 = @ps.runs.create!

        h = FactoryGirl.create(:host_with_parameters)
        host_param = { param1: "foo", param2: "bar" }
        mpi_procs = 1
        omp_threads = 4
        runs = @ps.find_or_create_runs_upto(3,
                                            submitted_to: h,
                                            host_param: host_param,
                                            mpi_procs: 1,
                                            omp_threads: 4 )
        expect( run1.reload.submitted_to ).to be_nil
        expect( run1.reload.omp_threads ).to eq 1
      end
    end

    context "when the speciefied number is smaller than or equal to the number of runs" do

      it "returns existing runs without creating" do
        3.times do |i|
          @ps.runs.create!
        end

        expect {
          runs = @ps.find_or_create_runs_upto(2)
          expect( runs.count ).to eq 2
        }.to_not change { @ps.runs.count }
      end
    end

    it "returned runs are soted by created_at" do
      r1 = @ps.runs.create!
      r2 = @ps.runs.create!
      runs = @ps.find_or_create_runs_upto(3)
      expect( runs[0..1] ).to eq [r1, r2]
    end
  end

  describe "#average_result" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0, finished_runs_count: 0)
      @ps = sim.parameter_sets.first
    end

    it "returns the average of the results" do
      [1,2,3,4,5].each do |r|
        @ps.runs.create!( status: :finished, result: {"r1"=>r} )
      end
      ave, n = @ps.average_result("r1")
      expect(ave).to eq 3.0
      expect(n).to eq 5
    end

    it "ignores unfinishd runs" do
      [1,2,3,4,5].each do |r|
        @ps.runs.create!( status: :finished, result: {"r1"=>r} )
      end
      @ps.runs.create!( status: :failed, result: {"r1"=>0} )
      @ps.runs.create!( status: :created )
      ave = @ps.average_result("r1")
      expect( @ps.average_result("r1") ).to eq [3.0, 5]
    end

    it "returns [nil,0] when runs are not found" do
      expect( @ps.average_result("r1") ).to eq [nil, 0]
    end

    context "when error:true option is given" do

      it "returns stderr as well" do
        [1,2,3,4,5].each do |r|
          @ps.runs.create!( status: :finished, result: {"r1"=>r} )
        end
        ave,n,err = @ps.average_result("r1", error: true)
        expect( ave ).to eq 3.0
        expect( n ).to eq 5
        expect( err ).to be_within(0.01).of(0.7071)
      end

      it "returns [nil,0,nil] when runs are not found" do
        expect( @ps.average_result("r1",error: true) ).to eq [nil,0,nil]
      end
    end
  end

  describe "#discard" do

    before(:each) do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1)
      @ps = sim.parameter_sets.first
    end

    it "updates 'to_be_destroyed' to true" do
      expect {
        @ps.discard
      }.to change { @ps.to_be_destroyed }.from(false).to(true)
    end

    it "should receive 'set_lower_submittable_to_be_destroyed'" do
      expect(@ps).to receive(:set_lower_submittable_to_be_destroyed)
      @ps.discard
    end
  end

  describe "#set_lower_submittable_to_be_destroyed" do

    before(:each) do
      sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1, run_analysis: true,
                                analyzers_on_parameter_set_count: 1,
                                run_analysis_on_parameter_set: true
                                )
      @ps = sim.parameter_sets.first
    end

    it "sets to_be_destroyed of lower Runs" do
      expect {
        @ps.set_lower_submittable_to_be_destroyed
      }.to change { @ps.reload.runs.empty? }.from(false).to(true)
    end

    it "sets to_be_destroyed of lower run-Analysis" do
      run = @ps.reload.runs.first
      expect {
        @ps.set_lower_submittable_to_be_destroyed
      }.to change { run.reload.analyses.empty? }.from(false).to(true)
    end

    it "sets to_be_destroyed of lower ps-Analysis" do
      expect {
        @ps.set_lower_submittable_to_be_destroyed
      }.to change { @ps.reload.analyses.empty? }.from(false).to(true)
    end
  end

  describe "#destroyable?" do
    before(:each) do
      sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1,
                                runs_count: 1,
                                analyzers_count: 1, run_analysis: true,
                                analyzers_on_parameter_set_count: 1,
                                run_analysis_on_parameter_set: true
                                )
      @ps = sim.parameter_sets.first
    end

    it "returns false when it has Run or Analysis" do
      expect(@ps.destroyable?).to be_falsey
    end

    it "returns true when all the Run or Analysis is destroyed" do
      @ps.set_lower_submittable_to_be_destroyed
      expect( @ps.destroyable? ).to be_falsey
      @ps.runs.first.analyses.unscoped.destroy
      expect( @ps.destroyable? ).to be_falsey
      @ps.runs.unscoped.destroy
      expect( @ps.destroyable? ).to be_falsey
      @ps.analyses.unscoped.destroy
      expect( @ps.destroyable? ).to be_truthy
    end
  end

  describe "#destroy" do

    it "deletes result_directory" do
      ps = @sim.parameter_sets.first
      dir = ps.dir
      ps.destroy
      expect(File.directory?(dir)).to be_falsey
    end
  end
end
