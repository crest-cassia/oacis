# -*- encoding: utf-8 -*-
require 'spec_helper'

describe ParameterSetQuery do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count: 1, 
                              runs_count: 1
                              )
    @sim.save
  end
  
  describe "validation for a Float format" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"gte" => 4.0}}
                            )
    }

    it {should be_valid}
  end

  describe "validation for a invalid type" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"gte" => "4.0"}}
                            )
    }

    it {should_not be_valid}
  end

  describe "validation for a invalid matcher" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"match" => "4.0"}}
                            )
    }

    it {should_not be_valid}
  end

  describe "validation for presence" do

    subject {
      ParameterSetQuery.new(simulator: @sim, query: {})
    }

    it {should_not be_valid}
  end

  describe "validation for uniqueness" do


    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"gte" => 4.0}, "L"=>{"eq"=>2}}
                            )
    }

    it {should_not be_valid}
  end

  describe "#selector" do

    before(:each) do
      @query = @sim.parameter_set_queries.first
    end

    subject { @query }

    its(:selector) {should == Query.new.gte({"v.T" => 4.0}).where({"v.L" => 2}).selector}
  end

  describe "#set_query" do

    before(:each) do
      @query = @sim.parameter_set_queries.first
    end

    subject { @query }

    its(:set_query, [{"param"=>"T", "matcher"=>"gte", "value"=>"4.0", "logic"=>"and"},
                     {"param"=>"L", "matcher"=>"eq", "value"=>"2", "logic"=>"and"}
                    ]) {
      should == {"T" => {"gte" => 4.0}, "L"=>{"eq"=>2}}
    }
  end
end
