# -*- encoding: utf-8 -*-
require 'spec_helper'

describe ParameterSetQuery do

  before(:each) do
    @sim = FactoryBot.create(:simulator, 
                              parameter_sets_count: 1, runs_count: 0,
                              parameter_set_queries_count: 1
                              )
  end
  
  describe "validation for a Float format" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"gte" => 4.0}},
                            name: "filter1"
                            )
    }

    it {is_expected.to be_valid}
  end

  describe "validation for a invalid type" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"gte" => "4.0"}},
                            name: "filter1"
                            )
    }

    it {is_expected.not_to be_valid}
  end

  describe "validation for a invalid matcher" do

    subject {
      ParameterSetQuery.new(simulator: @sim,
                            query: {"T" => {"match" => "4.0"}},
                            name: "filter1"
                            )
    }

    it {is_expected.not_to be_valid}
  end

  describe "validation for presence of query" do

    subject {
      ParameterSetQuery.new(simulator: @sim, query: {}, name: "filter1")
    }

    it {is_expected.not_to be_valid}
  end

  describe "validation for uniqueness of query" do

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

  it "validate uniqueness of name" do
    psq1 = @sim.parameter_set_queries.create(query: {"T" => {"gte" => 4.0}}, name: "filter1")
    psq2 = @sim.parameter_set_queries.build(query: {"T" => {"gte" => 5.0}}, name: "filter1")
    expect(psq2).to_not be_valid
  end

  describe "#selector" do

    before(:each) do
      @query = FactoryBot.create(:parameter_set_query,
                                  simulator: @sim,
                                  query: {"L" => {"lte" => 123}, "T" => {"gte" => 456.0}},
                                  name: "filter1"
                                  )
    end

    it "has valid selector" do
      expect(@query.selector).to eq @sim.parameter_sets.where("v.L" => {"$lte" => 123}, "v.T" => {"$gte" => 456.0}).selector
    end
  end

  describe "#from_hash" do

    before(:each) do
      @psq = @sim.parameter_set_queries.build
      @arg = [{"param"=>"T", "matcher"=>"gte", "value"=>"4.0", "logic"=>"and"},
              {"param"=>"L", "matcher"=>"eq", "value"=>"2", "logic"=>"and"}]
    end

    it "updates 'query' field" do
      @psq.from_hash(@arg)
      expect(@psq.query).to eq({"T" => {"gte" => 4.0}, "L" => {"eq" => 2}})
    end

    it "returns a Hash when it successfully updates query field" do
      expect(@psq.from_hash(@arg)).to be_a(Hash)
    end

    it "returns false when argument is invalid" do
      expect(@psq.from_hash(nil)).to be_falsey
    end
  end

  describe "#serialize" do

    it "serialize query into JSON" do
      q = @sim.parameter_set_queries.build(name: "filter", query: {'T'=> {'gte'=>4.0},'L'=>{'lt'=>0}})
      j = q.serialize
      parsed = JSON.load(j)
      expect(parsed).to eq [['T','gte',4.0],['L','lt',0]]
    end
  end
end
