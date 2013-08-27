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

  it "should be valid with appropriate fields" do
    Simulator.new(@valid_fields).should be_valid
  end

  describe "'name' field" do

    it "must exist" do
      Simulator.new(@valid_fields.update(name:"")).should_not be_valid
    end

    it "must be unique" do
      Simulator.create!(@valid_fields)
      Simulator.new(@valid_fields).should_not be_valid
    end

    it "must be organized with word characters" do
      Simulator.new(@valid_fields.update({name:"b l a n k"})).should_not be_valid
    end

    it "is not editable after a parameter set is created" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      sim.name = "AnotherSimulator"
      sim.should_not be_valid
    end
  end

  describe "'command' field" do

    it "must exist" do
      invalid_attr = @valid_fields
      invalid_attr.delete(:command)
      Simulator.new(invalid_attr).should_not be_valid
    end
  end

  describe "parameter_sets" do

    before(:each) do
      @simulator = Simulator.create!(@valid_fields)
    end

    it "should have 'parameter_sets' method" do
      @simulator.should respond_to(:parameter_sets)
    end

    it "should return 'parameter_sets'" do
      @simulator.parameter_sets.should == []

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
      FileTest.directory?(ResultDirectory.simulator_path(sim)).should be_true
    end

    it "is not created when validation fails" do
      Simulator.create(@valid_fields.update(name:""))
      (Dir.entries(ResultDirectory.root) - ['.', '..']).should be_empty
    end
  end

  describe "'description' field" do

    it "responds to 'description'" do
      Simulator.new.should respond_to(:description)
    end
  end

  describe "#destroy" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
    end

    it "calls destroy of dependent parameter_sets when destroyed" do
      expect {
        @sim.destroy
      }.to change { ParameterSet.count }.by(-1)
    end

    it "calls destroy of dependent runs when destroyed" do
      expect {
        @sim.destroy
      }.to change { Run.count }.by(-1)
    end
  end

  describe "#dir" do

    it "returns the result directory of the simulator" do
      sim = FactoryGirl.create(:simulator, :parameter_sets_count => 0, :runs_count => 0, :parameter_set_queries_count => 0)
      sim.dir.should == ResultDirectory.simulator_path(sim)
    end
  end

  describe "#analyzers_on_run" do

    it "returns analyzers whose type is :on_run" do
      sim = FactoryGirl.create(:simulator, 
                               parameter_sets_count: 0,
                               runs_count: 0,
                               analyzers_count: 0,
                               parameter_set_queries_count:0
                               )
      FactoryGirl.create_list(:analyzer, 5,
                              type: :on_run,
                              simulator: sim)
      FactoryGirl.create_list(:analyzer, 5,
                              type: :on_parameter_set,
                              simulator: sim)

      sim.analyzers_on_run.should be_a(Mongoid::Criteria)
      sim.analyzers_on_run.should eq(sim.analyzers.where(type: :on_run))
      sim.analyzers_on_run.count.should eq(5)
    end
  end

  describe "#analyzers_on_parameter_set" do

    it "returns analyzers whose type is :on_parameter_set" do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 0,
                               runs_count: 0,
                               analyzers_count: 0,
                               parameter_set_queries_count:0
                               )
      FactoryGirl.create_list(:analyzer, 1,
                              type: :on_run,
                              simulator: sim)
      FactoryGirl.create_list(:analyzer, 2,
                              type: :on_parameter_set,
                              simulator: sim)

      sim.analyzers_on_parameter_set.should be_a(Mongoid::Criteria)
      sim.analyzers_on_parameter_set.should eq(sim.analyzers.where(type: :on_parameter_set))
      sim.analyzers_on_parameter_set.count.should eq(2)
    end
  end
end
