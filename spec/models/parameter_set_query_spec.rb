# -*- encoding: utf-8 -*-
require 'spec_helper'

describe ParameterSetQuery do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count: 1, runs_count: 0,
                              parameter_set_queries_count: 1
                              )
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

    context "with same simulator and query" do
      before(:each) do
        @sim.save
        @test_query = @sim.parameter_set_queries.build
        @test_query.query = {"T" => {"gte" => @sim.parameter_sets.first["v"]["L"]*2.0}, "L"=> {"lte" => @sim.parameter_sets.first["v"]["L"]}}
      end

      subject {
        @test_query
      }

      it {should_not be_valid}
    end

    context "with same simulator and modified query" do
      before(:each) do
        @sim.save
        @test_query = @sim.parameter_set_queries.build
        @test_query.query = {"L"=> {"lte" => @sim.parameter_sets.first["v"]["L"], "T" => {"gte" => @sim.parameter_sets.first["v"]["L"]*2.0}}}
      end

      subject {
        @test_query
      }

      it {should_not be_valid}
    end
  end

  describe "#selector" do

    before(:each) do
      @query = @sim.parameter_set_queries.first
    end

    subject { @query }

    its(:selector) {should == Query.new.gte({"v.T" => @sim.parameter_sets.first["v"]["L"]*2.0}).lte({"v.L" => @sim.parameter_sets.first["v"]["L"]}).selector}
  end

  describe "#set_query" do

    before(:each) do
      @query = @sim.parameter_set_queries.first
    end

    subject { @query }

    its(:set_query, [{"param"=>"T", "matcher"=>"gte", "value"=>"4.0", "logic"=>"and"},
                     {"param"=>"L", "matcher"=>"eq", "value"=>"2", "logic"=>"and"}
                    ]) {
      should_not be_false
    }
  end
end
