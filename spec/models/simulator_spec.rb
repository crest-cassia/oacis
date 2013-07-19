require 'spec_helper'

describe Simulator do

  before(:each) do
    @valid_fields = {
      name:"simulatorA",
      parameter_definitions: {
        "L" => {"type" => "Integer"},
        "T" => {"type" => "Float"}
      },
      command: "~/path_to_a_simulator",
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
  end

  describe "'command' field" do

    it "must exist" do
      invalid_attr = @valid_fields
      invalid_attr.delete(:command)
      Simulator.new(invalid_attr).should_not be_valid
    end
  end

  describe "'parameter_definitions' field" do
    
    it "must not be a blank" do
      Simulator.new(@valid_fields.update(parameter_definitions:{})).should_not be_valid
    end

    it "name of each key must be organized with word characters" do
      fields = @valid_fields.update(parameter_definitions:{"b lank"=>{"type"=>"String"}})
      Simulator.new(fields).should_not be_valid
    end

    it "each key must have a type" do
      fields = @valid_fields.update(parameter_definitions:{"L"=>{"default"=>32}})
      Simulator.new(fields).should_not be_valid
    end

    it "type of each key must be either 'Boolean', 'Integer', 'Float', or 'String'" do
      fields = @valid_fields.update(parameter_definitions:{
                                      "Boolean_key"=>{"type"=>"Boolean"},
                                      "Integer_key"=>{"type"=>"Integer"},
                                      "Float_key"=>{"type"=>"Float"},
                                      "String_key"=>{"type"=>"String"}
                                    })
      Simulator.new(fields).should be_valid
      fields[:parameter_definitions]["DateTime_key"] = {"type"=>"DateTime"}
      Simulator.new(fields).should_not be_valid
    end

    it "default values are casted according to its type" do
      fields = @valid_fields.update(parameter_definitions:{
                                      "Boolean_key"=>{"type"=>"Boolean", "default" => "true"},
                                      "Integer_key"=>{"type"=>"Integer", "default" => "1"},
                                      "Float_key"=>{"type"=>"Float", "default" => "0.12345e7"},
                                      "String_key"=>{"type"=>"String", "default" => "abc"}
                                    })
      sim = Simulator.new(fields)
      sim.valid?
      sim.parameter_definitions["Boolean_key"]["default"].should be_a(TrueClass)
      sim.parameter_definitions["Integer_key"]["default"].should be_a(Integer)
      sim.parameter_definitions["Float_key"]["default"].should be_a(Float)
      sim.parameter_definitions["String_key"]["default"].should be_a(String)
    end

    it "is invalid if default value can not be casted to the specified type" do
      fields = @valid_fields.update(parameter_definitions:{
                                      "Integer_key"=>{"type"=>"Integer", "default" => "foo"}
                                    })
      sim = Simulator.new(fields)
      sim.should_not be_valid
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

  describe "#analyzers_on_parameter_set_group" do

    it "returns analyzers whose type is :on_parameter_set_group" do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 0,
                               runs_count: 0,
                               analyzers_count: 0,
                               parameter_set_queries_count:0
                               )
      FactoryGirl.create_list(:analyzer, 1,
                              type: :on_run,
                              simulator: sim)
      FactoryGirl.create_list(:analyzer, 1,
                              type: :on_parameter_set,
                              simulator: sim)
      FactoryGirl.create_list(:analyzer, 2,
                              type: :on_parameter_set_group,
                              simulator: sim)

      sim.analyzers_on_parameter_set_group.should be_a(Mongoid::Criteria)
      sim.analyzers_on_parameter_set_group.should eq(sim.analyzers.where(type: :on_parameter_set_group))
      sim.analyzers_on_parameter_set_group.count.should eq(2)
    end
  end

  describe "analyses_on_parameter_set_group" do

    it "returns an array of all analyses belonging to analyzer" do
      sim = FactoryGirl.create(:simulator,
                               parameter_sets_count: 1,
                               runs_count: 0,
                               analyzers_count: 0,
                               parameter_set_queries_count:0
                               )
      azr = FactoryGirl.create(:analyzer, type: :on_parameter_set_group, simulator: sim, run_analysis: false)
      azr2 = FactoryGirl.create(:analyzer, type: :on_parameter_set_group, simulator: sim, run_analysis: false)
      psg = FactoryGirl.create(:parameter_set_group, parameter_sets: sim.parameter_sets.all, simulator: sim)
      FactoryGirl.create_list(:analysis, 3, analyzer: azr, analyzable: psg)
      FactoryGirl.create_list(:analysis, 3, analyzer: azr2, analyzable: psg)

      sim.analyses(azr).count.should eq 3
      sim.analyses(azr).each do |arn|
        arn.analyzer.should eq azr
      end
    end
  end
end
