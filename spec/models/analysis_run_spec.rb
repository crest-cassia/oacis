require 'spec_helper'

describe AnalysisRun do

  before(:each) do
    @sim = FactoryGirl.create(:simulator, 
                              parameter_sets_count:0, runs_count:0, analyzer_count: 2)
    @azr = @sim.analyzers.first
  end

  describe "validation" do

    before(:each) do
      parameters = {"param1" => 1, "param2" => 2.0}

      @valid_attr = {
        parameters: parameters
      }
    end

    it "is valid with proper attributes" do
      arn = @azr.analysis_runs.build(@valid_attr)
      arn.should be_valid
    end

    it "is invalid when 'parameters' field is not given" do
      arn = @azr.analysis_runs.build({})
      arn.should_not be_valid
    end

    it "assigns 'created' stauts by default" do
      arn = @azr.analysis_runs.create(@valid_attr)
      arn.status.should == :created
    end

    it "is invalid if Analyzer is not related" do
      arn = AnalysisRun.new(@valid_attr)
      arn.should_not be_valid
    end

    it "is invalid when status is not an allowed value" do
      arn = @azr.analysis_runs.create(@valid_attr)
      arn.status = :status_XXX
      arn.should_not be_valid
    end
  end

  describe "accessibility" do

    before(:each) do
      @valid_attr = {
        parameters: {"param1" => 1, "param2" => 2.0}
      }
    end

    it "result is not an accessible field" do
      arn = @azr.analysis_runs.create(@valid_attr.update(result: "abc"))
      arn.result.should be_nil
    end

    it "status is not an accessible field" do
      arn = @azr.analysis_runs.create(@valid_attr.update(status: :running))
      arn.status.should_not == :running
    end
  end
end
