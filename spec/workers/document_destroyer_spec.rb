require 'spec_helper'

describe DocumentDestroyer do

  let(:logger) { Logger.new( File.open('/dev/null','w') ) }

  describe "destroying Simulator" do

    it "destroys Simulator if it is destroyable" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0)

      sim.update_attribute(:to_be_destroyed, true)
      expect {
        DocumentDestroyer.perform(logger)
      }.to change { Simulator.unscoped.count }.from(1).to(0)
    end

    it "does not destroy Simulator if it is not destroyable" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1)

      sim.update_attribute(:to_be_destroyed, true)
      expect {
        DocumentDestroyer.perform(logger)
      }.to_not change { Simulator.unscoped.count }
    end
  end

  describe "destroying Runs" do

    it "destroys runs if its status is finished or failed and to_be_destroyed" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1,
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
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                               analyzers_count: 0)
      run = sim.parameter_sets.first.runs.first
      run.status = :created
      run.to_be_destroyed = true
      run.save!
      expect {
        DocumentDestroyer.perform(logger)
      }.to_not change { Run.unscoped.count }
    end

    context "when run is to_be_destroyed but analysis is not to_be_destroyed" do

      it "does not destroy run, but set analysis to_be_destroyed to true" do
        # run: to_be_destroyed=true
        #   |- analysis: to_be_destroyed=false
        # This can happen run#to_be_destroyed is set to true
        # while analysis is being created.
        sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1,
                                 analyzers_count: 1, run_analysis: false)
        run = sim.parameter_sets.first.runs.first
        run.status = :finished
        run.to_be_destroyed = true
        run.save!
        azr = sim.analyzers.first
        anl = run.analyses.create(analyzer: azr, submitted_to: azr.executable_on.first)

        expect {
          DocumentDestroyer.perform(logger)
        }.to_not change{ Run.unscoped.count }
        expect( anl.reload.to_be_destroyed ).to be_truthy
      end
    end
  end

  describe "destroying Analysis" do

    it "destroys analyses if its status is finished or failed and to_be_destroyed" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1,
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
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1,
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
