require 'spec_helper'

describe ParameterDefinition do

  describe "validation" do

    before(:each) do
      @valid_attr = {key: "L", type: "Integer", default: 30, description: "system size"}
    end

    it "is valid with appropriate fields" do
      pd = ParameterDefinition.new(@valid_attr)
      pd.should be_valid
    end

    describe "key field" do

      it "must exist" do
        @valid_attr.delete(:key)
        pd = ParameterDefinition.new(@valid_attr)
        pd.should_not be_valid
      end

      it "must be organized with word characters only" do
        pd = ParameterDefinition.new(@valid_attr.update(key: "b l a n k"))
        pd.should_not be_valid
      end

      it "must be unique within a simulator" do
        sim = Simulator.new(name: "simA", command: "echo")
        pd = sim.parameter_definitions.build(@valid_attr)
        pd.should be_valid
        pd2 = sim.parameter_definitions.build(@valid_attr)
        pd2.should_not be_valid
      end

      it "is valid if identical key is used in different simualtors" do
        simA = Simulator.new(name: "simA", command: "echo")
        simB = Simulator.new(name: "simB", command: "echo")
        pd1 = simA.parameter_definitions.build(@valid_attr)
        pd1.should be_valid
        pd2 = simB.parameter_definitions.build(@valid_attr)
        pd2.should be_valid
      end
    end

    describe "type field" do

      it "must be either Integer, Float, String, or Boolean" do
        pd = ParameterDefinition.new( @valid_attr.update(type: "DateTime") )
        pd.should_not be_valid
      end
    end

    describe "default field" do

      it "is casted properly to the specified type" do
        pd = ParameterDefinition.new( @valid_attr.update(default: "30") )
        pd.should be_valid
        pd.default.should eq be_an(Integer)
      end

      it "is not be valid when the default value can not be casted" do
        pd = ParameterDefinition.new( @valid_attr.update(default: "abc") )
        pd.should_not be_valid
      end

      it "is casted properly to the specified type(Boolean)" do
        pd = ParameterDefinition.new( @valid_attr.update(type: "Boolean",default: false) )
        pd.should be_valid
        pd = ParameterDefinition.new( @valid_attr.update(type: "Boolean",default: true) )
        pd.should be_valid
      end 
    end

    describe "description field" do

      it "can be blank" do
        @valid_attr.delete(:description)
        pd = ParameterDefinition.new(@valid_attr)
        pd.should be_valid
      end
    end
  end
end
