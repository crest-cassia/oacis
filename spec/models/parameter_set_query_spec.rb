# -*- encoding: utf-8 -*-
require 'spec_helper'

describe ParameterSetQuery do

  #pending "add some examples to (or delete) #{__FILE__}"
  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count: 1, 
                              runs_count: 1
                              )
    @sim.save
  end
  
  describe "validation pattern1" do

    before(:each) do
      @query = @sim.parameter_set_querys.first
    end

    subject { @query }

    it {should be_valid}
  end

  describe "validation pattern2" do

    before(:each) do
      @query = @sim.parameter_set_querys.first
      @query.query = {"T" => {"gte" => "4.0"}}
    end

    subject { @query }

    it {should_not be_valid}
  end

  describe "validation pattern3" do

    before(:each) do
      @query = @sim.parameter_set_querys.first
      @query.query = {"T" => {"match" => "4.0"}}
    end

    subject { @query }

    it {should_not be_valid}
  end

  describe "validation pattern4" do

    before(:each) do
      @query = @sim.parameter_set_querys.first
      @query.query = {}
    end

    subject { @query }

    it {should_not be_valid}
  end
  # describe "validation pattern5" do
    # before(:each) do
      # @query = FactoryGirl.create(:parameter_set_query,
                              # simulator: @sim,
                              # query: {"T" => {"gte" => 4.0}, "L"=>{"eq"=>2}}
                              # )
      # @query.query = {"T" => {"gte" => 4.0}}
    # end
    # subject { @query }
    # it {should_not be_valid}
  # end
  describe "get_selector" do

    before(:each) do
      @query = @sim.parameter_set_querys.first
    end

    subject { @query }

    its(:get_selector) {should == Query.new.gte({"v.T" => 4.0}).where({"v.L" => 2}).selector}
  end

  describe "set_selector" do

    before(:each) do
      @query = @sim.parameter_set_querys.first
    end

    subject { @query }

    its(:set_query, {"utf8"=>"✓",
                    "_method"=>"put",
                    "authenticity_token"=>"G2dpxUzQhT6WboU635UqQ8/p87o+xQYGq/Cdyr7wmkc=",
                    "param"=>["L","T"],
                    "macher"=>["eq","gte"],
                    "value"=>["2","4.0"],
                    "commit"=>"Make query",
                    "action"=>"_apply_query",
                    "controller"=>"simulators",
                    "id"=>"5191905e81e31e8e4100000b"}) {should == {"T" => {"gte" => 4.0}, "L"=>{"eq"=>2}}}

    after(:all) do

      subject { @query }

      its(:get_selector) {should == Query.new.gte({"v.T" => 4.0}).where({"v.L" => 2}).selector}
    end
  end
end
