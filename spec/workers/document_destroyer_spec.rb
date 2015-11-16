require 'spec_helper'

describe JobSubmitter do

  let(:logger) { Logger.new($stderr) }

  describe "destroying Simulator" do

    it "destroys Simulator if it is destroyable" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)

      sim.update_attribute(:to_be_destroyed, true)
      expect {
        DocumentDestroyer.perform(logger)
      }.to change { Simulator.unscoped.count }.from(1).to(0)
    end

    it "does not destroy Simulator if it is not destroyable" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)

      sim.update_attribute(:to_be_destroyed, true)
      expect {
        DocumentDestroyer.perform(logger)
      }.to_not change { Simulator.unscoped.count }
    end

    it "calls set_lower_submittable_to_be_destroyed when it's not destroyable for 10 times" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      sim.update_attribute(:to_be_destroyed, true)
      expect_any_instance_of(Simulator).to receive(:set_lower_submittable_to_be_destroyed).once
      10.times do |t|
        DocumentDestroyer.perform(logger)
      end
    end
  end

  describe "destroying Runs" do

    it "destroys runs if its status is finished or failed and to_be_destroyed" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 0)
      run = sim.parameter_sets.first.runs.first
      run.status = :finished
      run.to_be_destroyed = true
      run.save!
      expect {
        DocumentDestroyer.perform(logger)
      }.to change { Run.unscoped.count }.by(-1)
    end

    it "does not destroy if it is not finished or failed" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 0)
      run = sim.parameter_sets.first.runs.first
      run.status = :created
      run.to_be_destroyed = true
      run.save!
      expect {
        DocumentDestroyer.perform(logger)
      }.to_not change { Run.unscoped.count }
    end
  end

  describe "destroying Analysis" do

    it "destroys analyses if its status is finished or failed and to_be_destroyed" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 1, run_analysis: true)
      anl = sim.parameter_sets.first.runs.first.analyses.first
      anl.status = :finished
      anl.to_be_destroyed = true
      anl.save!
      expect {
        DocumentDestroyer.perform(logger)
      }.to change { Analysis.unscoped.count }.by(-1)
    end

    it "does not destroy if it is not finished or failed" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 1, run_analysis: true)
      anl = sim.parameter_sets.first.runs.first.analyses.first
      anl.status = :created
      anl.to_be_destroyed = true
      anl.save!
      expect {
        DocumentDestroyer.perform(logger)
      }.to_not change { Analysis.unscoped.count }
    end
  end
end
