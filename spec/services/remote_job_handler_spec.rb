require 'spec_helper'

describe RemoteJobHandler do

  describe ".remote_status" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 1)
      @run = @sim.parameter_sets.first.runs.first
      @run.job_id = "12345"
      @host = @sim.executable_on.where(name: "localhost").first
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!
      SSHUtil.stub(:execute2).and_return(["out", "err", 0, nil])
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "returns status parsed by SchedulerWrapper#parse_remote_status" do
      SchedulerWrapper.any_instance.should_receive(:parse_remote_status).and_return(:submitted)
      RemoteJobHandler.new(@host).remote_status(@run).should eq :submitted
    end

    it "returns :unknown if remote status is not obtained by SchedulerWrapper" do
      SSHUtil.stub(:execute2).and_return([nil, nil, 1, nil])
      RemoteJobHandler.new(@host).remote_status(@run).should eq :unknown
    end
  end
end