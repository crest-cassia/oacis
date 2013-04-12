require 'spec_helper'

describe Simulator do

  before(:each) do
    @valid_fields = {
      name:"simulatorA",
      parameter_keys: {
        "L" => {"type" => "Integer"},
        "T" => {"type" => "Float"}
      },
      execution_command: "~/path_to_a_simulator",
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

  describe "'execution_command' field" do

    it "must exist" do
      invalid_attr = @valid_fields
      invalid_attr.delete(:execution_command)
      Simulator.new(invalid_attr).should_not be_valid
    end
  end

  describe "'parameter_keys' field" do
    
    it "must not be a blank" do
      Simulator.new(@valid_fields.update(parameter_keys:{})).should_not be_valid
    end

    it "name of each key must be organized with word characters" do
      fields = @valid_fields.update(parameter_keys:{"b lank"=>{"type"=>"String"}})
      Simulator.new(fields).should_not be_valid
    end

    it "each key must have a type" do
      fields = @valid_fields.update(parameter_keys:{"L"=>{"default"=>32}})
      Simulator.new(fields).should_not be_valid
    end

    it "type of each key must be either 'Boolean', 'Integer', 'Float', or 'String'" do
      fields = @valid_fields.update(parameter_keys:{
                                      "Boolean_key"=>{"type"=>"Boolean"},
                                      "Integer_key"=>{"type"=>"Integer"},
                                      "Float_key"=>{"type"=>"Float"},
                                      "String_key"=>{"type"=>"String"}
                                    })
      Simulator.new(fields).should be_valid
      fields[:parameter_keys]["DateTime_key"] = {"type"=>"DateTime"}
      Simulator.new(fields).should_not be_valid
    end
  end

  describe "parameters" do

    before(:each) do
      @simulator = Simulator.create!(@valid_fields)
    end

    it "should have 'parameters' method" do
      @simulator.should respond_to(:parameters)
    end

    it "should return 'parameters'" do
      @simulator.parameters.should == []

      param_attribute = {:sim_parameters => {"L" => 32, "T" => 0.1} }
      @simulator.parameters.create!(param_attribute)
      @simulator.parameters.count == 1
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
      Dir.entries(ResultDirectory.root).should == ['.', '..'] # i.e. empty directory
    end
  end
end
