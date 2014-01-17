require 'spec_helper'

describe Host do

  describe "validations" do

    before(:each) do
      @valid_attr = {
        name: "nameABC",
        hostname: "localhost",
        user: ENV['USER'],
        port: 22,
        ssh_key: '~/.ssh/id_rsa',
        scheduler_type: 'none',
        work_base_dir: '~/__cm_work__',
      }
    end

    it "'name' must be present" do
      @valid_attr.delete(:name)
      Host.new(@valid_attr).should_not be_valid
    end

    it "'name' must be unique" do
      Host.create!(@valid_attr)
      Host.new(@valid_attr).should_not be_valid
    end

    it "'name' must not be an empty string" do
      @valid_attr.update(name: '')
      Host.new(@valid_attr).should_not be_valid
    end

    it "'hostname' must be present" do
      @valid_attr.delete(:hostname)
      Host.new(@valid_attr).should_not be_valid
    end

    it "'hostname' must conform to a format of hostname" do
      @valid_attr.update(hostname: 'hostname;')
      Host.new(@valid_attr).should_not be_valid
      @valid_attr.update(hostname: 'xn--bcher-kva.ch.')
      Host.new(@valid_attr).should be_valid
    end

    it "'user' must be present" do
      @valid_attr.delete(:user)
      Host.new(@valid_attr).should_not be_valid
    end

    it "format of the 'user' must be valid" do
      @valid_attr.update(user: 'user-XYZ')
      Host.new(@valid_attr).should be_valid
      @valid_attr.update(user: 'user;XYZ')
      Host.new(@valid_attr).should_not be_valid
    end

    it "default of 'port' is 22" do
      @valid_attr.delete(:port)
      Host.new(@valid_attr).port.should eq(22)
    end

    it "'port' must be between 1..65535" do
      @valid_attr.update(port: 'abc')  # => casted to 0
      Host.new(@valid_attr).should_not be_valid
    end

    it "default of 'ssh_key' is '~/.ssh/id_rsa'" do
      @valid_attr.delete(:ssh_key)
      Host.new(@valid_attr).ssh_key.should eq('~/.ssh/id_rsa')
    end

    it "default of 'work_base_dir' is '~'" do
      @valid_attr.delete(:work_base_dir)
      Host.new(@valid_attr).work_base_dir.should eq('~')
    end

    it "has timestamp fields" do
      host = Host.new(@valid_attr)
      host.should respond_to(:created_at)
      host.should respond_to(:updated_at)
    end

    it "max_num_jobs must be 0 or positive number" do
      @valid_attr.update(max_num_jobs: -1)
      host = Host.new(@valid_attr)
      host.should_not be_valid
    end

    it "min_mpi_procs must be 1 or positive" do
      @valid_attr.update(min_mpi_procs: 0)
      host = Host.new(@valid_attr)
      host.should_not be_valid
    end

    it "max_mpi_procs must be 1 or positive" do
      @valid_attr.update(max_mpi_procs: 0)
      host = Host.new(@valid_attr)
      host.should_not be_valid
    end

    it "max_mpi_procs must be larger than min_mpi_procs" do
      @valid_attr.update(min_mpi_procs: 2, max_mpi_procs: 1)
      host = Host.new(@valid_attr)
      host.should_not be_valid
    end

    it "min_omp_threads must be 1 or positive" do
      @valid_attr.update(min_omp_threads: 0)
      host = Host.new(@valid_attr)
      host.should_not be_valid
    end

    it "max_omp_threads must be 1 or positive" do
      @valid_attr.update(max_omp_threads: 0)
      host = Host.new(@valid_attr)
      host.should_not be_valid
    end

    it "max_omp_threads must be larger than min_omp_threads" do
      @valid_attr.update(min_omp_threads: 2, max_omp_threads: 1)
      host = Host.new(@valid_attr)
      host.should_not be_valid
    end

    it "cannot change when submitted runs exist" do
      host = FactoryGirl.create(:host)
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      ps = sim.parameter_sets.first
      run = ps.runs.create!(submitted_to: host)
      run.update_attribute(:status, :submitted)
      host.work_base_dir = "/path/to/another_dir"
      host.should_not be_valid
    end

    it "is valid when host_parameter_definitions conform to template" do
      template_header = <<-EOS
#!/bin/bash
#node: <%= node %>
EOS
      template = JobScriptUtil::DEFAULT_TEMPLATE.sub("#!/bin/bash", template_header)
      definitions = [HostParameterDefinition.new(key: "node")]
      host = FactoryGirl.build(:host, template: template, host_parameter_definitions: definitions)
      host.should be_valid
    end

    it "is not valid when host_parameter_definitions does not have sufficient variables" do
      template_header = <<-EOS
#!/bin/bash
#node: <= node %>
#elapsed: <%= elapsed %>
EOS
      template = JobScriptUtil::DEFAULT_TEMPLATE.sub("#!/bin/bash", template_header)
      definitions = [HostParameterDefinition.new(key: "node")]
      host = FactoryGirl.build(:host, template: template, host_parameter_definitions: definitions)
      host.should_not be_valid
    end

    it "is not valid when there is a host_parameter_definitions which is not found in template" do
      template_header = <<-EOS
#!/bin/bash
#node: <= node %>
EOS
      template = JobScriptUtil::DEFAULT_TEMPLATE.sub("#!/bin/bash", template_header)
      definitions = [
        HostParameterDefinition.new(key: "node"),
        HostParameterDefinition.new(key: "elapsed")
      ]
      host = FactoryGirl.build(:host, template: template, host_parameter_definitions: definitions)
      host.should_not be_valid
    end

    it "can not be destroyed when submittable_runs or submitted_runs exist" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      run = sim.parameter_sets.first.runs.first
      host = run.submitted_to
      host.destroy.should be_false
      host.errors.full_messages.should_not be_empty
    end

    it "can be destroyed when neither submittable_runs nor submitted_runs exist" do
      sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      run = sim.parameter_sets.first.runs.first
      run.update_attribute(:status, :finished)
      host = run.submitted_to
      host.destroy.should be_true
      host.errors.full_messages.should be_empty
    end
  end

  describe "#connected?" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
    end

    it "returns true if ssh connection established" do
      @host.connected?.should be_true
    end

    it "returns false when hostname is invalid" do
      @host.hostname = "INVALID_HOSTNAME"
      @host.connected?.should be_false
    end

    it "returns false when user name is not correct" do
      @host.user = "NOT_EXISTING_USER"
      @host.connected?.should be_false
    end

    it "exception is stored into connection_error variable" do
      @host.hostname = "INVALID_HOSTNAME"
      @host.connected?
      @host.connection_error.should be_a(SocketError)
    end
  end

  describe "#status" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
    end

    it "returns status of hosts" do
      pending "not yet implemented"
    end
  end

  describe "#submittable_runs" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 2, runs_count: 0)
      @host = FactoryGirl.create(:host)
      @sim.executable_on.push @host
      @sim.parameter_sets.each do |ps|
        3.times do |i|
          ps.runs.create!(submitted_to: @host)
        end
        2.times do |i|
          run = ps.runs.create!(submitted_to: @host)
          run.update_attribute(:status, :finished)
        end
      end
    end

    it "returns a Mongoid::Critieria" do
      @host.submittable_runs.should be_a(Mongoid::Criteria)
    end

    it "returns runs whose status is created and submitted_to is self" do
      @host.submittable_runs.should have(6).items
    end

    it "does not return runs whose submitted_to is not self" do
      another_host = FactoryGirl.create(:host)
      @sim.parameter_sets.each do |ps|
        1.times do |i|
          run = ps.runs.create!(submitted_to: @host)
          run.submitted_to = @host
          run.save!
        end
        2.times do |i|
          run = ps.runs.create!(submitted_to: @host)
          run.submitted_to = another_host
          run.save!
        end
      end

      @host.submittable_runs.should have(8).items
      @host.submittable_runs.each do |run|
        run.submitted_to.should_not eq another_host
      end
    end
  end

  describe "#submitted_runs" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 0)
      @host = FactoryGirl.create(:host)
      host2 = FactoryGirl.create(:host)
      ps = @sim.parameter_sets.first
      FactoryGirl.create_list(:run, 3,
                              parameter_set: ps, status: :submitted, submitted_to: @host)
      FactoryGirl.create_list(:run, 1,
                              parameter_set: ps, status: :running, submitted_to: @host)
      run = ps.runs.where(status: :submitted).first.__send__(:cancel)
      FactoryGirl.create_list(:run, 1,
                              parameter_set: ps, status: :finished, submitted_to: @host)
      FactoryGirl.create_list(:run, 2,
                              parameter_set: ps, status: :submitted, submitted_to: host2)
    end

    it "returns the number of runs submitted to the host" do
      @host.submitted_runs.should be_a(Mongoid::Criteria)
    end

    it "returns runs whose status is ['submitted','running','cancelled'] and 'submitted_to' is the host" do
      @host.submitted_runs.should have(4).items
    end
  end

  describe "#check_submitted_job_status" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 1)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host = @sim.executable_on.where(name: "localhost").first
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!

      @run = @sim.parameter_sets.first.runs.first
      @run.status = :submitted
      @run.submitted_to = @host
      @run.save!

      @logger = Logger.new( @temp_dir.join('log.txt') )
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "do nothing if remote_status is 'submitted'" do
      RemoteJobHandler.any_instance.should_receive(:remote_status).and_return(:submitted)
      @host.check_submitted_job_status(@logger)
      @run.status.should eq :submitted
    end

    it "update status to 'running' when remote_status of Run is 'running'" do
      RemoteJobHandler.any_instance.should_receive(:remote_status).and_return(:running)
      @host.check_submitted_job_status(@logger)
      @run.reload.status.should eq :running
    end

    it "include remote data and update status to 'finished' or 'failed'" do
      RemoteJobHandler.any_instance.should_receive(:remote_status).and_return(:includable)
      JobIncluder.should_receive(:include_remote_job) do |host, run|
        run.id.should eq @run.id
      end
      @host.check_submitted_job_status(@logger)
    end

    context "when run is cancelled" do

      before(:each) do
        @run.status = :cancelled
        @run.save!
      end

      it "cancelles a remote job" do
        RemoteJobHandler.any_instance.should_receive(:cancel_remote_job) # do nothing
        @host.check_submitted_job_status(@logger)
      end

      it "destroys run" do
        RemoteJobHandler.any_instance.stub(:remote_status) { :includable }
        expect {
          @host.check_submitted_job_status(@logger)
        }.to change { Run.count }.by(-1)
      end

      it "does not include remote data even if remote status is 'includable'" do
        @host.stub(:remote_status) { :includable }
        JobIncluder.should_not_receive(:include_remote_job)
        @host.check_submitted_job_status(@logger)
      end
    end
  end
end
