require 'spec_helper'

describe SchedulerWrapper do

  it "is initialized with a correct type" do
    possible_types = SchedulerWrapper::TYPES.each do |type|
      expect {
        SchedulerWrapper.new(type)
      }.to_not raise_error
    end
  end

  it "raises an exception with an invalid type" do
    expect {
      SchedulerWrapper.new("invalid")
    }.to raise_error
  end

  describe "torque" do

    before(:each) do
      @wrapper = SchedulerWrapper.new("torque")
    end

    describe "#submit_command" do

      it "returns a command to submit a job" do
        @wrapper.submit_command("~/path/to/job.sh").should eq "qsub ~/path/to/job.sh"
      end
    end

    describe "#status_command" do

      it "returns a command to show the status of the host" do
        @wrapper.status_command("job_id").should eq "qstat job_id"
      end
    end

    describe "#parse_remote_status" do

      it "parses standard output of the status_command" do
        stdout = <<EOS
Job id                    Name             User            Time Use S Queue
------------------------- ---------------- --------------- -------- - -----
123.hostname              job.sh           example                0 R batch
EOS
        @wrapper.parse_remote_status(stdout).should eq :running
      end
    end

    describe "#cancel_command" do

      it "returns command to cancel a job" #IMPLEMENT ME
    end
  end
end