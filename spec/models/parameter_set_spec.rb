require 'spec_helper'

describe ParameterSet do

  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 1,
                              runs_count: 1
                              )
    @valid_attr = {:v => {"L" => 32, "T" => 1.0}}
  end

  describe "validation" do

    it "should create a Parameter when valid attributes are given" do
      expect {
        @sim.parameter_sets.create!(@valid_attr)
      }.not_to raise_error
    end

    it "should not be balid when simulator is not related" do
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

    it "calls destroy of dependent runs when destroyed" do
      run = @ps.runs.first
      expect(run).to receive(:destroy)
      @ps.destroy
    end

    it "calls destroy of dependent analyses when destroyed" do
      azr = FactoryGirl.create(:analyzer,
                         simulator: @sim,
                         type: :on_parameter_set
                         )
      anl = @ps.analyses.build(analyzable: @ps, analyzer: azr)
      expect(anl).to receive(:destroy)
      @ps.destroy
    end

    it "calls cancel of dependent runs whose status is submitted or running when destroyed" do
      run = @ps.runs.first
      run.status = :submitted
      expect(run).to receive(:cancel)
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
      @prm = sim.parameter_sets.first
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
      expect(prm.runs_status_count[:cancelled]).to eq prm.runs.where(status: :cancelled).count
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

  describe "#destroy" do

    it "deletes result_directory" do
      ps = @sim.parameter_sets.first
      dir = ps.dir
      ps.destroy
      expect(File.directory?(dir)).to be_falsey
    end
  end
end
