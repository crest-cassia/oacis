require 'spec_helper'

describe AnalysisRun do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count:1, runs_count:1, analyzers_count: 1)
    @run = @sim.parameter_sets.first.runs.first
    @azr = @sim.analyzers.first
    @valid_attr = {
        parameters: {"param1" => 1, "param2" => 2.0},
        analyzer: @azr
    }
  end

  describe "validation" do

    it "is valid with proper attributes" do
      arn = @run.analysis_runs.build(@valid_attr)
      arn.should be_valid
    end

    it "is invalid when 'parameters' field is not given" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:parameters)
      arn = @run.analysis_runs.build(invalid_attr)
      arn.should_not be_valid
    end

    it "assigns 'created' stauts by default" do
      arn = @run.analysis_runs.create!(@valid_attr)
      arn.status.should == :created
    end

    it "is invalid if Analyzer is not related" do
      invalid_attr = @valid_attr
      invalid_attr.delete(:analyzer)
      arn = @run.analysis_runs.build(invalid_attr)
      arn.should_not be_valid
    end

    it "is invalid if there is no parent document" do
      arn = AnalysisRun.new(@valid_attr)
      lambda {
        arn.save!
      }.should raise_error
    end

    it "is invalid when status is not an allowed value" do
      arn = @run.analysis_runs.create!(@valid_attr)

      arn.status = :status_XXX
      arn.should_not be_valid
    end

    it "casts the parameter values according to the definition" do
      updated_attr = @valid_attr.update(parameters: {"param1"=>"32","param2"=>"2.0"})
      arn = @run.analysis_runs.create!(updated_attr)
      arn.parameters["param1"].should be_a(Integer)
      arn.parameters["param2"].should be_a(Float)
    end
  end

  describe "accessibility" do

    it "result is not an accessible field" do
      arn = @run.analysis_runs.build(@valid_attr.update(result: "abc"))
      arn.result.should be_nil
    end

    it "status is not an accessible field" do
      arn = @run.analysis_runs.build(@valid_attr.update(status: :running))
      arn.status.should_not == :running
    end
  end

  describe "relation" do

    it "can be embedded in a run" do
      @arn = @run.analysis_runs.build(@valid_attr)
      @arn.save!
      @run.analysis_runs.last.should be_a(AnalysisRun)
      @arn.analyzable.should be_a(Run)
    end

    it "can be embedded in a parameter_set" do
      ps = @sim.parameter_sets.first
      @arn = ps.analysis_runs.build(@valid_attr)
      @arn.save!
      ps.analysis_runs.last.should be_a(AnalysisRun)
      @arn.analyzable.should be_a(ParameterSet)
    end

    it "refers to analyzer" do
      @arn = @run.analysis_runs.create!(@valid_attr)
      @arn.reload
      @arn.analyzer.should be_a(Analyzer)
    end
  end
end
