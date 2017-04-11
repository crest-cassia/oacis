require 'spec_helper'

describe OacisWatcher do

  before(:each) do
    @sim = FactoryGirl.create(:simulator,
                              parameter_sets_count: 2,
                              runs_count: 0
                             )
    @watcher = OacisWatcher.new( logger: Logger.new('/dev/null') )
  end

  describe "#watch_ps" do

    it "registers a callback function for a ParameterSet" do
      expect {
        @watcher.watch_ps( @sim.parameter_sets.first) {}
      }.to change { @watcher.instance_variable_get(:@observed_parameter_sets).size }.by(1)
    end

    it "registers multiple callback functions for a ParameterSet" do
      ps = @sim.parameter_sets.first
      @watcher.watch_ps(ps) {}
      @watcher.watch_ps(ps) {}
      expect( @watcher.instance_variable_get(:@observed_parameter_sets)[ps.id].size ).to eq 2
    end
  end

  describe "#watch_all_ps" do

    it "registers a callback function for a set of ParameterSet" do
      expect {
        @watcher.watch_all_ps( @sim.parameter_sets ) {}
      }.to change { @watcher.instance_variable_get(:@observed_parameter_sets_all).size }.by(1)
    end

    it "registers multiple callback functions for a set of ParameterSet" do
      @watcher.watch_all_ps( @sim.parameter_sets ) {}
      @watcher.watch_all_ps( @sim.parameter_sets ) {}
      expect( @watcher.instance_variable_get(:@observed_parameter_sets_all).first[1].size ).to eq 2
    end
  end

  describe "#completed?" do

    it "returns true if all runs are finished or failed" do
      ps = @sim.parameter_sets.first
      runs = FactoryGirl.create_list(:finished_run, 3, parameter_set: ps)
      runs.first.update_attribute(:status, :failed)
      expect( @watcher.send(:completed?, ps) ).to be_truthy
    end

    it "returns false if not all runs are finished or failed" do
      ps = @sim.parameter_sets.first
      finished = FactoryGirl.create_list(:finished_run, 2, parameter_set: ps)
      not_finished = FactoryGirl.create(:run, parameter_set: ps)
      expect( @watcher.send(:completed?, ps) ).to be_falsey
    end
  end

  describe "#completed_ps_ids" do

    it "returns an array of completed ParameterSet from the given set of ParameterSet" do
      ps1 = @sim.parameter_sets.asc(:id).first
      ps2 = @sim.parameter_sets.asc(:id).last
      FactoryGirl.create_list(:finished_run, 3, parameter_set: ps1)
      FactoryGirl.create_list(:run, 3, parameter_set: ps2)
      expect( @watcher.send(:completed_ps_ids, @sim.parameter_sets.map(&:id)) ).to eq [ps1.id]
    end
  end

  describe "#check_completed_ps" do

    it "calls registered callback functions" do
      ps1,ps2 = @sim.parameter_sets[0..1]
      mock1 = double("callback mock")
      mock2 = double("callback mock")
      @watcher.watch_ps(ps1) {|ps| mock1.callback }
      @watcher.watch_ps(ps2) {|ps| mock2.callback }
      FactoryGirl.create(:finished_run, parameter_set: ps1)
      FactoryGirl.create(:run, parameter_set: ps2)
      expect( mock1 ).to receive(:callback)
      expect( mock2 ).to_not receive(:callback)
      ret = @watcher.send(:check_completed_ps)
      expect( ret ).to be_truthy
    end

    it "stops when a new run is created during a callback function" do
      ps = @sim.parameter_sets.first
      FactoryGirl.create(:finished_run, parameter_set: ps)
      mock1 = double("mock")
      mock2 = double("mock")
      @watcher.watch_ps(ps) {|ps| ps.runs.create(submitted_to: @sim.executable_on.first); mock1.callback } # create a new run
      @watcher.watch_ps(ps) {|ps| mock2.callback }  # second callback function
      expect( mock1 ).to receive(:callback)
      expect( mock2 ).to_not receive(:callback)
      ret = @watcher.send(:check_completed_ps)
      expect( ret ).to be_truthy
    end

    it "returns false if no callback is called" do
      ps = @sim.parameter_sets.first
      FactoryGirl.create(:run, parameter_set: ps)
      @watcher.watch_ps(ps) {}
      ret = @watcher.send(:check_completed_ps)
      expect( ret ).to be_falsey
    end
  end

  describe "#check_completed_ps_all" do

    it "calls registered callback functions when all PS is completed" do
      ps1, ps2 = @sim.parameter_sets[0..1]
      FactoryGirl.create(:finished_run, parameter_set: ps1)
      FactoryGirl.create(:finished_run, parameter_set: ps2)
      mock1 = double("mock")
      expect( mock1 ).to receive(:callback)
      @watcher.watch_all_ps( [ps1,ps2] ) {|pss|
        expect( pss.to_a ).to match_array [ps1,ps2]
        mock1.callback
      }
      ret = @watcher.send(:check_completed_ps_all)
      expect( ret ).to be_truthy
    end

    it "does not call callback when all PS is not completed" do
      ps1,ps2 = @sim.parameter_sets[0..1]
      FactoryGirl.create(:finished_run, parameter_set: ps1)
      FactoryGirl.create(:run, parameter_set: ps2)
      mock1 = double("mock")
      expect( mock1 ).to_not receive(:callback)
      @watcher.watch_all_ps( [ps1,ps2] ) { mock1.callback }
      ret = @watcher.send(:check_completed_ps_all)
      expect( ret ).to be_falsey
    end

    it "can call watch_all_ps recursively" do
      ps1, ps2 = @sim.parameter_sets[0..1]
      FactoryGirl.create(:finished_run, parameter_set: ps1)
      FactoryGirl.create(:finished_run, parameter_set: ps2)
      mock1 = double("mock")
      expect( mock1 ).to receive(:callback)
      @watcher.watch_all_ps( [ps1] ) {|_|
        @watcher.watch_all_ps( [ps2] ) {|pss|
          expect( pss.to_a ).to match_array [ps2]
          mock1.callback
        }
      }

      2.times do |t| # the nested callback is called after checked twice
        ret = @watcher.send(:check_completed_ps_all)
        expect( ret ).to be_truthy
      end
    end
  end
end

