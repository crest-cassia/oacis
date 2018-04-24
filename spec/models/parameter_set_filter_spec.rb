require 'spec_helper'

describe ParameterSetFilter do

  before(:each) do
    @sim = FactoryBot.create(:simulator, 
                              parameter_sets_count: 1, runs_count: 0,
                              parameter_set_filters_count: 1
                              )
  end
  
  describe "validation for a Float format" do

    it "should be valid" do
      q = @sim.parameter_set_filters.build(conditions: [["T", "gte", 4.0]], name: "filter1")
      expect(q).to be_valid
    end
  end

  describe "validation for a invalid type" do

    it "should not be valid" do
      q = @sim.parameter_set_filters.build(conditions: [["T", "match", "foobar"]], name: "filter1")
      expect(q).to_not be_valid
    end
  end

  describe "validation for a invalid matcher" do

    it "should not be valid" do
      q = @sim.parameter_set_filters.build(conditions: [["T", "match", 3.2]], name: "filter1")
      expect(q).to_not be_valid
    end
  end

  describe "validation for presence of conditions" do

    it "should not be valid" do
      q = @sim.parameter_set_filters.build(conditions: [], name: "filter1")
      expect(q).to_not be_valid
    end
  end

  describe "#selector" do

    it "has valid selector" do
      query = @sim.parameter_set_filters.build(name: 'filter1', conditions: [["L", "lte", 123], ["T", "gte", 456.0]])
      expect(query.selector).to eq @sim.parameter_sets.where("v.L" => {"$lte" => 123}, "v.T" => {"$gte" => 456.0}).selector
    end

    it "has valid selector" do
      query = @sim.parameter_set_filters.build(name: 'filter2', conditions: [["L", "lte", 123], ["L", "gte", 10], ["T", "lt", 2.8]])
      expect(query.selector).to eq @sim.parameter_sets.where("v.L" => {"$lte" => 123, "$gte" => 10}, "v.T" => {'$lt'=> 2.8}).selector
    end
  end

  describe "when values are given by string" do

    it "values are casted according to its types before validation" do
      q = [["T","gte","3.5"],["L","eq","2"]]
      psq = @sim.parameter_set_filters.build(name: 'f', conditions: q)
      expect(psq).to be_valid
      expect(psq.conditions).to eq([["T","gte",3.5],["L","eq",2]])
    end

    it "returns false when argument is invalid" do
      q = [["T","gte","foo"],["L","eq","2"]]
      psq = @sim.parameter_set_filters.build(name: 'f', conditions: q)
      expect(psq).to_not be_valid
    end
  end

  describe ".format" do

    it "formats a readable string from a condition" do
      str1 = ParameterSetFilter.format(["T","gte",3.5],)
      expect(str1).to eq "T >= 3.5"
      str2 = ParameterSetFilter.format(["S","match","foobar"],)
      expect(str2).to eq "S match foobar"
    end
  end
end
