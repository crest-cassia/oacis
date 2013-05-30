require 'spec_helper'

describe Analyzer do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, parameter_sets_count:0, runs_count:0)
  end

  describe "validations" do

    before(:each) do
      param_def = {
        "initial_skip" => {
          "type" => "Integer",
          "default" => 0,
          "description" => "Number of steps for which analysis is skipped"
        }
      }
      @valid_fields = {
        name: "time_series_analyzer",
        type: :on_run,
        parameter_definitions: param_def,
        command: "ruby ~/path/to/time_series_analyzer.rb",
        description: "time series analysis"
      }
    end

    it "is valid with appropriate fields" do
      analyzer = @sim.analyzers.build(@valid_fields)
      analyzer.should be_a(Analyzer)
      analyzer.should be_valid
    end

    describe "'name' field" do

      it "must exist" do
        analyzer = @sim.analyzers.build(@valid_fields.update(name:""))
        analyzer.should_not be_valid
      end

      it "must be unique" do
        @sim.analyzers.create!(@valid_fields)
        analyzer = @sim.analyzers.build(@valid_fields)
        analyzer.should_not be_valid
      end

      it "must be organized with letters, numbers, and underscores" do
        analyzer = @sim.analyzers.build(@valid_fields.update({name:"b l a n k"}))
        analyzer.should_not be_valid
      end
    end

    describe "'type' field" do

      it "must exist" do
        invalid_fields = @valid_fields
        invalid_fields.delete(:type)
        azr = @sim.analyzers.build(invalid_fields)
        azr.should_not be_valid
      end

      it "must be either 'on_run', 'on_parameter_set', 'on_several_parameter_sets'" do
        invalid_fields = @valid_fields.update({type: "on_xxx"})
        azr = @sim.analyzers.build(invalid_fields)
        azr.should_not be_valid
      end
    end

    describe "'command' field" do

      it "must have 'command'" do
        invalid_attr = @valid_fields
        invalid_attr.delete(:command)
        azr = @sim.analyzers.build(invalid_attr)
        azr.should_not be_valid
      end
    end

    describe "'parameter_definitions' field" do
      
      it "can be a empty" do
        azr = @sim.analyzers.build(@valid_fields.update(parameter_definitions:{}))
        azr.should be_valid
      end

      it "can be nil" do
        @valid_fields.delete(:parameter_definitions)
        azr = @sim.analyzers.build(@valid_fields)
        pp azr.errors unless azr.valid?
        azr.should be_valid
      end

      it "name of each key must be organized with letters, numbers, and underscores" do
        invalid_attr = @valid_fields.update(parameter_definitions:{"b lank"=>{"type"=>"String"}})
        azr = @sim.analyzers.build(invalid_attr)
        azr.should_not be_valid
      end

      it "each key must have a type" do
        invalid_attr = @valid_fields.update(parameter_definitions:{"x"=>{"default"=>32}})
        azr = @sim.analyzers.build(invalid_attr)
        azr.should_not be_valid
      end

      it "type of each key must be either 'Boolean', 'Integer', 'Float', or 'String'" do
        fields = @valid_fields.update(parameter_definitions:{
                                        "Boolean_key"=>{"type"=>"Boolean"},
                                        "Integer_key"=>{"type"=>"Integer"},
                                        "Float_key"=>{"type"=>"Float"},
                                        "String_key"=>{"type"=>"String"}
                                      })
        @sim.analyzers.build(fields).should be_valid

        fields[:name] = "another_analyzer"
        fields[:parameter_definitions]["DateTime_key"] = {"type"=>"DateTime"}
        @sim.analyzers.build(fields).should_not be_valid
      end
    end

    describe "'description' field" do

      it "can be blank" do
        fields = @valid_fields
        fields.delete(:description)
        @sim.analyzers.build(fields).should be_valid
      end
    end
  end
end
