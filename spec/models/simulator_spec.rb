require 'spec_helper'

describe Simulator do

  before(:each) do
    @valid_fields = {
      name:"a_simulator",
      parameter_keys: {
        "L" => {"type" => "Integer"},
        "T" => {"type" => "Float"}
      },
      # run_parameter_keys: {"seed" => {type:"Integer"}},
      execution_command: "~/path_to_a_simulator",
      analysis_methods: ["calculate_average", "calculate_variance"]
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

  describe "'parameter_keys' field" do
    
    it "must not be a blank" do
      Simulator.new(@valid_fields.update(parameter_keys:{})).should_not be_valid
    end

    it "name of each key must organized with word characters" do
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

end
