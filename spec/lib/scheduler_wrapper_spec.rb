require 'spec_helper'

describe SchedulerWrapper do

  before(:each) do
    @host = FactoryBot.create(:localhost)
    @wrapper = SchedulerWrapper.new(@host)
  end

  it "raises an exception with an invalid type" do
    expect {
      SchedulerWrapper.new("invalid")
    }.to raise_error(/Not a host/)
  end

  describe "#submit_command" do

    it "returns a command to submit a job from work_dir" do
      work_dir = File.join(@host.work_base_dir, "xxx")
      log_dir = File.join(@host.work_base_dir, "xxx_log")
      expected = "bash -l -c 'echo XSUB_BEGIN && xsub ~/path/to/job.sh -d #{work_dir} -l #{log_dir} -p \\{\\}'"
      expect(@wrapper.submit_command("~/path/to/job.sh","xxx")).to eq expected
    end

    context "when host parameters are required" do

      it "command includes host-parameters in json" do
        work_dir = File.join(@host.work_base_dir, "xxx")
        log_dir = File.join(@host.work_base_dir, "xxx_log")
        expected = <<EOS.chomp
bash -l -c 'echo XSUB_BEGIN && xsub ~/path/to/job.sh -d #{work_dir} -l #{log_dir} -p \\{\\\"param1\\\":\\\"1\\\",\\\"param2\\\":\\\"2\\\"\\}'
EOS
        expect(@wrapper.submit_command("~/path/to/job.sh","xxx",{param1:"1",param2:"2"})).to eq expected
      end
    end
  end

  describe "#all_status_command" do

    it "returns a command to show the status of all the jobs in the host" do
      expect(@wrapper.all_status_command).to match(/bash -l -c 'xstat'/)
    end
  end

  describe "#status_command" do

    it "returns a command to show the status of the host" do
      expect(@wrapper.status_command("job_id")).to match(/bash -l -c 'echo XSUB_BEGIN && xstat job_id/)
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
      expect(@wrapper.parse_remote_status(stdout)).to eq :running
    end
  end

  describe "#cancel_command" do

    it "returns command to cancel a job" do
      expect(@wrapper.cancel_command("job_id")).to eq "bash -l -c 'xdel job_id; echo $?'"
    end
  end
end
