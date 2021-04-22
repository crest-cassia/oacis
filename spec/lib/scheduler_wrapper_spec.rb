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
      expected = "xsub ~/path/to/job.sh -d #{work_dir} -l #{log_dir} -p \\{\\}"
      expect(@wrapper.submit_command("~/path/to/job.sh","xxx")).to eq expected
    end

    context "when host parameters are required" do

      it "command includes host-parameters in json" do
        work_dir = File.join(@host.work_base_dir, "xxx")
        log_dir = File.join(@host.work_base_dir, "xxx_log")
        expected = <<EOS.chomp
xsub ~/path/to/job.sh -d #{work_dir} -l #{log_dir} -p \\{\\\"param1\\\":\\\"1\\\",\\\"param2\\\":\\\"2\\\"\\}
EOS
        expect(@wrapper.submit_command("~/path/to/job.sh","xxx",{param1:"1",param2:"2"})).to eq expected
      end
    end
  end

  describe "#all_status_command" do

    it "returns a command to show the status of all the jobs in the host" do
      expect(@wrapper.all_status_command).to eq("xstat")
    end
  end

  describe "#status_command" do

    it "returns a command to show the status of the host" do
      expect(@wrapper.status_command("job_id")).to eq("xstat job_id")
    end
  end

  describe "#parse_remote_status" do

    it "parses standard output of the status_command" do
      stdout = <<EOS
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

  describe "#status_multiple_command" do

    it "returns a command to show the statuses of the host" do
      expect(@wrapper.status_multiple_command(["job_id0", "job_id1", "job_id2"])).to eq("xstat -m job_id0 job_id1 job_id2")
    end
  end

  describe "#parse_remote_status_multiple" do

    it "parses standard output of the status_multiple_command" do
      stdout = <<-EOS
        {
          "123": {
            "status": "running",
            "raw_output": [
              "  PID TTY           TIME CMD",
              "  123 ??        25:13.39 ./a.out"
            ]
          },
          "234": {
            "status": "finished",
            "raw_output": [
              "  PID TTY           TIME CMD"
            ]
          }
        }
      EOS
      expect(@wrapper.parse_remote_status_multiple(stdout)).to eq({"123" => :running, "234" => :includable})
    end
  end

  describe "#cancel_command" do

    it "returns command to cancel a job" do
      expect(@wrapper.cancel_command("job_id")).to eq "xdel job_id"
    end
  end
end
