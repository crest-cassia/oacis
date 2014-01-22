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

  describe "none" do

    before(:each) do
      @wrapper = SchedulerWrapper.new("none")
    end

    describe "#submit_command" do

      it "returns a command to submit a job" do
        @wrapper.submit_command("~/path/to/job.sh").should eq "nohup bash ~/path/to/job.sh > /dev/null 2>&1 < /dev/null & basename ~/path/to/job.sh"
      end
    end

    describe "#all_status_command" do

      it "returns a command to show the status of all the jobs in the host" do
        @wrapper.all_status_command.should eq "ps ux"
      end
    end

    describe "#status_command" do

      it "returns a command to show the status of the host" do
        @wrapper.status_command("job_id").should eq 'ps ux | grep "[j]ob_id"'
      end
    end

    describe "#parse_remote_status" do

      it "parses standard output of the status_command" do
        stdout = <<EOS
user 35112   0.0  0.0  2433432    956 s002  SN    9:00AM   0:00.00 bash /path/to/job.sh
EOS
        @wrapper.parse_remote_status(stdout).should eq :running
      end
    end

    describe "#cancel_command" do

      it "returns command to cancel a job" do
        cmd = "kill -- -`ps x -o \"pgid pid command\" | grep \"[j]ob_id\" | awk '{print $1}'`"
        @wrapper.cancel_command("job_id").should eq cmd
      end
    end
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

    describe "#all_status_command" do

      it "returns a command to show the status of all the jobs in the host" do
        @wrapper.all_status_command.should match(/qstat/)
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

      it "returns command to cancel a job" do
        @wrapper.cancel_command("job_id").should eq "qdel job_id"
      end
    end
  end

  describe "pjm_k" do

    before(:each) do
      @wrapper = SchedulerWrapper.new("pjm_k")
    end

    describe "#submit_command" do

      it "returns a command to submit a job" do
        @wrapper.submit_command("~/path/to/job.sh").should eq "bash -l -c \"cat ~/path/to/job.sh | pjsub\""
      end
    end

    describe "#all_status_command" do

      it "returns a command to show the status of all the jobs in the host" do
        @wrapper.all_status_command.should match(/pjstat/)
      end
    end

    describe "#status_command" do

      it "returns a command to show the status of the host" do
        @wrapper.status_command("job_id").should eq "pjstat job_id"
      end
    end

    describe "#parse_remote_status" do

      it "parses standard output of the status_command" do
        stdout = <<EOS

  ACCEPT QUEUED  STGIN  READY RUNING RUNOUT STGOUT   HOLD  ERROR   TOTAL
       0      1      0      0      0      0      0      0      0       1
s      0      1      0      0      0      0      0      0      0       1

JOB_ID     JOB_NAME   MD ST  USER     START_DATE      ELAPSE_LIM NODE_REQUIRE   
123    J52df5c2a8 NM RUN a03116   -               0000:05:00 1 
EOS
        @wrapper.parse_remote_status(stdout).should eq :running
      end
    end

    describe "#cancel_command" do

      it "returns command to cancel a job" do
        @wrapper.cancel_command("job_id").should eq "pjdel job_id"
      end
    end
  end
end
