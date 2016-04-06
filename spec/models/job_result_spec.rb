require 'spec_helper'

describe JobResult do

  before(:each) do
    @simulator = FactoryGirl.create(:simulator,
                                    parameter_sets_count: 1,
                                    runs_count: 1,
                                    analyzers_count: 2,
                                    run_analysis: true
                                    )
    @param_set = @simulator.parameter_sets.first
    @valid_attribute = {
      submitted_to: Host.first
    }
  end

  describe "when submittable is destroied" do

    it "is destroyed by run" do

      run=Run.first
      run.create_job_result(submittable_parameter: run.parameter_set, result: {result: "foo"})
      expect {
        run.destroy
      }.to change { JobResult.count }.by(-1)
    end
    
    it "is destroyed by analysis" do

      anl=Analysis.first
      anl.create_job_result(submittable_parameter: anl.analyzer, result: {result: "bar"})
      expect {
        anl.destroy
      }.to change { JobResult.count }.by(-1)
    end
  end

  describe "when it is destoroied" do

    it "don't destroy its submittable and its submittable_parameter" do

      run=Run.first
      run.create_job_result(submittable_parameter: run.parameter_set, result: {result: "foo"})
      job_result = run.job_result
      expect {
        job_result.destroy
      }.not_to change { Run.count }
      anl=Analysis.first
      anl.create_job_result(submittable_parameter: anl.analyzer, result: {result: "bar"})
      job_result = anl.job_result
      expect {
        job_result.destroy
      }.not_to change { Analysis.count }
      
    end
  end
end
