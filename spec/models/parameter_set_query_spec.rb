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

    it {is_expected.to be_valid}
  end

  describe "validation for a invalid type" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"gte" => "4.0"}}
                            )
    }

    it {is_expected.not_to be_valid}
  end

  describe "validation for a invalid matcher" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"match" => "4.0"}}
                            )
    }

    it {is_expected.not_to be_valid}
  end

  describe "validation for presence" do

    subject {
      ParameterSetQuery.new(simulator: @sim, query: {})
    }

    it {is_expected.not_to be_valid}
  end

  describe "validation for uniqueness" do

    context "with same simulator and query" do
      before(:each) do
        psq = @sim.parameter_set_queries.first
        @test_query = @sim.parameter_set_queries.build
        @test_query.query = psq.query
      end

      subject {
        @test_query
      }

      it {is_expected.not_to be_valid}
    end
  end

  describe "#selector" do

    before(:each) do
      @query = FactoryGirl.create(:parameter_set_query,
                                  simulator: @sim,
                                  query: {"L" => {"lte" => 123}, "T" => {"gte" => 456.0}}
                                  )
    end

    it "has valid selector" do
      expect(@query.selector).to eq @sim.parameter_sets.where("v.L" => {"$lte" => 123}, "v.T" => {"$gte" => 456.0}).selector
    end
  end

  describe "#set_query" do

    before(:each) do
      @psq = @sim.parameter_set_queries.build
      @arg = [{"param"=>"T", "matcher"=>"gte", "value"=>"4.0", "logic"=>"and"},
              {"param"=>"L", "matcher"=>"eq", "value"=>"2", "logic"=>"and"}]
    end

    it "updates 'query' field" do
      @psq.set_query(@arg)
      expect(@psq.query).to eq({"T" => {"gte" => 4.0}, "L" => {"eq" => 2}})
    end

    it "returns a Hash when it successfuly updates query field" do
      expect(@psq.set_query(@arg)).to be_a(Hash)
    end

    it "returns false when argument is invalid" do
      expect(@psq.set_query(nil)).to be_falsey
    end
  end
end
