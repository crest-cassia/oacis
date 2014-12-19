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
        status: :enabled
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

    it "'user' can include '.'" do
      @valid_attr.update(user: 'user.XYZ')
      Host.new(@valid_attr).should be_valid
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

    it "'scheduler_type' must be either [none, torque, pjm, pjm_k, xsub]" do
      @valid_attr.update(scheduler_type: "foobar")
      Host.new(@valid_attr).should_not be_valid
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

    it "polling_interval must greater than or equal to 5" do
      @valid_attr.update(polling_interval: 4)
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

    it "status must be either ':enabled' or ':disabled'" do
      @valid_attr.update(status: :disabled)
      host = Host.new(@valid_attr)
      host.should be_valid
      @valid_attr.update(status: :running)
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

  describe "#runs_status_count" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 0)
      @host = FactoryGirl.create(:host)
      host2 = FactoryGirl.create(:host)
      ps = @sim.parameter_sets.first
      FactoryGirl.create_list(:run, 5,
                              parameter_set: ps, status: :created, submitted_to: @host)
      FactoryGirl.create_list(:run, 4,
                              parameter_set: ps, status: :submitted, submitted_to: @host)
      FactoryGirl.create_list(:run, 3,
                              parameter_set: ps, status: :running, submitted_to: @host)
      FactoryGirl.create_list(:run, 2,
                              parameter_set: ps, status: :finished, submitted_to: @host)
      FactoryGirl.create_list(:run, 1,
                              parameter_set: ps, status: :failed, submitted_to: @host)
      FactoryGirl.create_list(:run, 2,
                              parameter_set: ps, status: :submitted, submitted_to: host2)
    end

    it "returns the number of runs for each status" do
      expected = {created: 5, submitted: 4, running: 3, finished: 2, failed: 1, cancelled: 0}
      @host.runs_status_count.should eq expected
    end
  end

  describe "when 'xsub' is selected as the scheduler_type" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
    end

    it "gets host parameters by invoking 'get_host_parameters_for_xsub' when scheduler_type is updated" do
      @host.scheduler_type = "xsub"
      @host.should_receive(:get_host_parameters_for_xsub)
      @host.should be_valid # it calls before_validate
    end

    it "gets host parameters by invoking 'get_host_parameters_for_xsub' when host status is changed into :enabled" do
      @host.update_attribute(:scheduler_type, "xsub")
      @host.update_attribute(:status, :disabled)
      @host.should_receive(:get_host_parameters_for_xsub)
      @host.status = :enabled
      @host.save!
    end

    it "parse output of 'xsub -t' and set it to host_parameter_definitions" do
      hp = {"parameters" => {"foo" => {"default"=>1}, "bar" => {"default"=>"abc"} } }
      ret_str = "XSUB_BEGIN\n#{hp.to_json}"
      SSHUtil.stub(:execute).and_return(ret_str)
      @host.scheduler_type = "xsub"
      @host.save!
      @host.host_parameter_definitions.size.should eq 2
      @host.host_parameter_definitions[0].key.should eq "foo"
      @host.host_parameter_definitions[0].default.should eq "1"
    end

    it "'xsub' command fails, validation fails" do
      SSHUtil.stub(:execute).and_return("{invalid:...")
      @host.scheduler_type = "xsub"
      @host.should_not be_valid
    end
  end

  describe "'position' field" do

    before(:each) do
      FactoryGirl.create_list(:host, 2)
    end

    it "the largest number within existing hosts is assigned when created" do
      Host.create!(name: 'h1', hostname: 'localhost', user: 'foo').position.should eq 2
      Host.all.map(&:position).should =~ [0,1,2]
    end
  end

  describe "#destroy" do

    before(:each) do
      @host = FactoryGirl.create(:host_with_parameters)
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0, finished_runs_count: 1)
      @sim.executable_on.destroy
      @sim.executable_on << @host
      @sim.save
    end

    it "delete host parameters from executable simulators" do
      host_id = @host.id.to_s
      host_parameters = @sim.default_host_parameter(@host)
      expect {
        @host.destroy
      }.to change { @sim.reload.default_host_parameters[host_id] }.from(host_parameters).to(nil)
    end
  end

  describe "#clear_host_parameters_in_executable_simulators" do

    before(:each) do
      @host = FactoryGirl.create(:host_with_parameters)
      @sim = FactoryGirl.create(:simulator, parameter_sets_count: 1, runs_count: 0, finished_runs_count: 1)
      @sim.executable_on.destroy
      @sim.executable_on << @host
      @sim.save
    end

    it "delete host_parameters in executable simulators" do
      host_id = @host.id.to_s
      host_parameters = @sim.default_host_parameter(@host)
      @host.status.should eq :enabled
      expect {
        @host.status = :disabled
        @host.save
      }.to change { @sim.reload.default_host_parameters[host_id] }.from(host_parameters).to(nil)
    end
  end
end
