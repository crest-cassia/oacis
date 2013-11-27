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
      lambda {
        @sim.parameter_sets.create!(@valid_attr)
      }.should_not raise_error
    end

    it "should not be balid when simulator is not related" do
      param = ParameterSet.new(@valid_attr)
      param.should_not be_valid
    end

    it "should not be valid when v does not exist" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:v)
      built_param = @sim.parameter_sets.build(invalid_attr)
      built_param.should_not be_valid
    end

    it "should raise an error when v is not a Hash" do
      invalid_attr = @valid_attr.update({v: "xxx"})
      lambda {
        @sim.parameter_sets.build(invalid_attr)
      }.should raise_error
    end

    it "should not be valid when keys of v are not consistent with its Simulator" do
      pd = @sim.parameter_definitions.first
      pd.default = nil
      built_param = @sim.parameter_sets.build(@valid_attr.update({:v => {}}))
      built_param.should_not be_valid
    end

    it "should not be valid when v is not unique" do
      @sim.parameter_sets.create!(@valid_attr)
      built = @sim.parameter_sets.build(@valid_attr)
      built.should_not be_valid
      err = built.errors.messages
      err.should have_key(:parameters)
      err[:parameters].find {|x|
        x =~ /identical/
      }.should be_true
    end

    it "identical v is valid for a differnet simulator" do
      @sim.parameter_sets.create!(@valid_attr)

      sim2 = FactoryGirl.create(:simulator,
                                parameter_sets_count: 0)
      built_param = sim2.parameter_sets.build(@valid_attr)
      built_param.should be_valid
    end

    it "should cast the values of v properly" do
      updated_attr = @valid_attr.update(:v => {"L"=>"32","T"=>"2.0"})
      built = @sim.parameter_sets.build(updated_attr)
      built.should be_valid
      built[:v]["L"].should == 32
      built[:v]["T"].should == 2.0
    end

    it "uses default values if a parameter value is not given" do
      updated_attr = @valid_attr.update(v: {})
      @sim.parameter_definition_for("L").default = 30
      @sim.parameter_definition_for("T").default = 2.0
      built = @sim.parameter_sets.build(updated_attr)
      built.should be_valid
      built[:v]["L"].should == 30
      built[:v]["T"].should == 2.0
    end

    it "should be valid once it is saved with valid attributes" do
      prm = @sim.parameter_sets.first
      prm.should be_valid
    end
  end

  describe "relations" do

    before(:each) do
      @ps = @sim.parameter_sets.first
    end

    it "has simulator method" do
      @ps.should respond_to(:simulator)
    end

    it "has runs method" do
      @ps.should respond_to(:runs)
    end

    it "calls destroy of dependent runs when destroyed" do
      run = @ps.runs.first
      run.should_receive(:destroy)
      @ps.destroy
    end

    it "calls destroy of dependent analyses when destroyed" do
      azr = FactoryGirl.create(:analyzer,
                         simulator: @sim,
                         type: :on_parameter_set
                         )
      anl = @ps.analyses.build(analyzable: @ps, analyzer: azr)
      anl.should_receive(:destroy)
      @ps.destroy
    end

    it "calls cancel of dependent runs whose status is submitted or running when destroyed" do
      run = @ps.runs.first
      run.status = :submitted
      run.should_receive(:cancel)
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
      FileTest.directory?(ResultDirectory.parameter_set_path(prm)).should be_true
    end

    it "is not created when validation fails" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 0)
      h = sim.parameter_definition_for("T")
      h.default = nil
      h.save!

      prm = sim.parameter_sets.create(@valid_attr.update({:v => {"L"=>"abc"}}))
      (Dir.entries(ResultDirectory.simulator_path(sim)) - ['.','..']).should be_empty
    end
  end

  describe "#dir" do

    it "returns the result directory of the parameter" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      prm = sim.parameter_sets.first
      prm.dir.should == ResultDirectory.parameter_set_path(prm)
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
      @prm = sim.parameter_sets.first
    end

    it "returns parameter_sets whose sim_parameter is same as self except for the specified key" do
      prms_L = @prm.parameter_sets_with_different("L")
      prms_L.count.should == 5
      prms_L.each do |prm_L|
        prm_L.v["T"].should == @prm.v["T"]
      end

      prms_T = @prm.parameter_sets_with_different("T")
      prms_T.count.should == 5
      prms_T.each do |prm_T|
        prm_T.v["L"].should == @prm.v["L"]
      end
    end

    it "includes self" do
      found = @prm.parameter_sets_with_different("L").find(@prm)
      found.should be_a(ParameterSet)
    end

    it "returns parameter_sets sorted by the given key" do
      prms_L = @prm.parameter_sets_with_different("L")
      prms_L.map {|x| x.v["L"]}.should eq [1,2,3,4,5]
    end

    context "when irrelevant keys are given" do

      it "ignores irrelevant keys when searching parameter sets" do
        prms_L = @prm.parameter_sets_with_different("L", ["P"])
        prms_L.map {|x| x.v["L"]}.should eq [1,1,1,1,1,2,3,3,4,5]
      end
    end
  end

  describe "#parameter_keys_having_distinct" do

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
      @prm.parameter_keys_having_distinct.should eq ["L", "T"]
    end
  end

  describe "#runs_status_count" do

    it "returns the runs count" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 10)
      prm = sim.parameter_sets.first
      prm.runs_status_count[:total] = prm.runs.count
      prm.runs_status_count[:finished].should == prm.runs.where(status: :finished).count
      prm.runs_status_count[:running].should == prm.runs.where(status: :running).count
      prm.runs_status_count[:failed].should == prm.runs.where(status: :failed).count
    end
  end

  describe "#destroy" do

    it "deletes result_directory" do
      ps = @sim.parameter_sets.first
      dir = ps.dir
      ps.destroy
      File.directory?(dir).should be_false
    end
  end
end
