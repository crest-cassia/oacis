require 'spec_helper'

RSpec.describe SaveTask, type: :model do

  before(:each) do
    @sim = FactoryBot.create(:simulator,
                             parameter_sets_count: 0,
                             runs_count: 0)
  end

  describe "#make_ps_in_batches" do

    before(:each) do
      @host_id = @sim.executable_on.first.id.to_s
    end

    it "makes PSs and Runs immediately when number of PS is less than 10" do
      task = @sim.save_tasks.create(param_values: {"L"=>[1,2,3], "T"=>[4.0,5.0,6.0]}, run_params: {submitted_to: @host_id}, num_runs: 1)
      task.make_ps_in_batches(true)
      expect(ParameterSet.count).to eq 9
      expect(Run.count).to eq 9
    end

    context "when the requested number of PS is more than 10" do

      it "makes 10 PSs immediately" do
        task = @sim.save_tasks.create(param_values: {"L"=>[1,2,3,4,5], "T"=>[4.0,5.0,6.0]}, run_params: {submitted_to: @host_id}, num_runs: 3)

        task.make_ps_in_batches(true)
        expect(ParameterSet.count).to eq 10
        expect(Run.count).to eq 0
      end

      it "makes the remaining PSs and Runs later" do
        task = @sim.save_tasks.create(param_values: {"L"=>[1,2,3,4,5], "T"=>[4.0,5.0,6.0]}, run_params: {submitted_to: @host_id}, num_runs: 3)
        task.make_ps_in_batches(true)

        task.make_ps_in_batches()
        expect(ParameterSet.count).to eq 15
        expect(Run.count).to eq 45
      end
    end

    context "when Simulator#sequential_seed is true" do

      it "makes sequential seeds on Runs" do
        @sim.update_attribute(:sequential_seed, true)
        task = @sim.save_tasks.create(param_values: {"L"=>[1,2,3,4,5], "T"=>[4.0,5.0,6.0]}, run_params: {submitted_to: @host_id}, num_runs: 3)
        task.make_ps_in_batches(true)

        task.make_ps_in_batches()
        @sim.parameter_sets.asc(:created_at).each do |ps|
          seeds = ps.runs.asc(:created_at).map(&:seed)
          expect(seeds).to eq [1,2,3]
        end
      end
    end
  end
end
