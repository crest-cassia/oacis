require 'spec_helper'

describe SchedulerWrapper do

  before(:each) do
    @host = FactoryGirl.create(:localhost)
  end

  it "is initialized with a correct type" do
    SchedulerWrapper::TYPES.each do |type|
      @host.update_attribute(:scheduler_type, type)
      expect {
        SchedulerWrapper.new(@host)
      }.to_not raise_error
    end
  end

  it "raises an exception with an invalid type" do
    expect {
      SchedulerWrapper.new("invalid")
    }.to raise_error
  end

  describe "xsub" do

    before(:each) do
      @host.update_attribute(:scheduler_type, "xsub")
      @wrapper = SchedulerWrapper.new(@host)
    end

    describe "#submit_command" do

      it "returns a command to submit a job from work_dir" do
        work_dir = File.join(@host.work_base_dir, "xxx")
        log_dir = File.join(@host.work_base_dir, "xxx_log")
        expected = "bash -l -c 'echo XSUB_BEGIN && xsub ~/path/to/job.sh -d #{work_dir} -l #{log_dir} -p \\{\\}'"
        @wrapper.submit_command("~/path/to/job.sh","xxx").should eq expected
      end

      context "when host parameters are required" do

        it "command includes host-parameters in json" do
          work_dir = File.join(@host.work_base_dir, "xxx")
          log_dir = File.join(@host.work_base_dir, "xxx_log")
          expected = <<EOS.chomp
bash -l -c 'echo XSUB_BEGIN && xsub ~/path/to/job.sh -d #{work_dir} -l #{log_dir} -p \\{\\\"param1\\\":\\\"1\\\",\\\"param2\\\":\\\"2\\\"\\}'
EOS
          @wrapper.submit_command("~/path/to/job.sh","xxx",{param1:"1",param2:"2"}).should eq expected
        end
      end
    end

    describe "#all_status_command" do

      it "returns a command to show the status of all the jobs in the host" do
        @wrapper.all_status_command.should match(/bash -l -c 'xstat'/)
      end
    end

    describe "#status_command" do

      it "returns a command to show the status of the host" do
        @wrapper.status_command("job_id").should eq "bash -l -c 'echo XSUB_BEGIN && xstat job_id'"
      end
    end

    describe "#parse_remote_status" do

      it "parses standard output of the status_command" do
        stdout = <<EOS
XSUB_BEGIN
{
  "status": "running",
  "raw_output": [
    "Job id                    Name             User            Time Use S Queue",
    "------------------------- ---------------- --------------- -------- - -----",
    "123.hostname              job.sh           example                0 R batch"
  ]
}
EOS
        @wrapper.parse_remote_status(stdout).should eq :running
      end
    end

    describe "#cancel_command" do

      it "returns command to cancel a job" do
        @wrapper.cancel_command("job_id").should eq "bash -l -c 'xdel job_id'"
      end
    end
  end
end
