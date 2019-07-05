require 'spec_helper'

describe Host do

  describe "validations" do

    before(:each) do
      @valid_attr = {
        name: "nameABC",
        work_base_dir: '~/__cm_work__',
        status: :enabled
      }
      allow_any_instance_of(Host).to receive(:get_host_parameters) do
        []
      end
    end

    it "'name' must be present" do
      @valid_attr.delete(:name)
      expect(Host.new(@valid_attr)).not_to be_valid
    end

    it "'name' must be unique" do
      Host.create!(@valid_attr)
      expect(Host.new(@valid_attr)).not_to be_valid
    end

    it "'name' must not be an empty string" do
      @valid_attr.update(name: '')
      expect(Host.new(@valid_attr)).not_to be_valid
    end

    it "default of 'work_base_dir' is '~'" do
      @valid_attr.delete(:work_base_dir)
      expect(Host.new(@valid_attr).work_base_dir).to eq('~')
    end

    it "has timestamp fields" do
      host = Host.new(@valid_attr)
      expect(host).to respond_to(:created_at)
      expect(host).to respond_to(:updated_at)
    end

    it "max_num_jobs must be 0 or positive number" do
      @valid_attr.update(max_num_jobs: -1)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "polling_interval must greater than or equal to 5" do
      @valid_attr.update(polling_interval: 4)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "min_mpi_procs must be 1 or positive" do
      @valid_attr.update(min_mpi_procs: 0)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "max_mpi_procs must be 1 or positive" do
      @valid_attr.update(max_mpi_procs: 0)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "max_mpi_procs must be larger than min_mpi_procs" do
      @valid_attr.update(min_mpi_procs: 2, max_mpi_procs: 1)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "min_omp_threads must be 1 or positive" do
      @valid_attr.update(min_omp_threads: 0)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "max_omp_threads must be 1 or positive" do
      @valid_attr.update(max_omp_threads: 0)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "max_omp_threads must be larger than min_omp_threads" do
      @valid_attr.update(min_omp_threads: 2, max_omp_threads: 1)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "status must be either ':enabled' or ':disabled'" do
      @valid_attr.update(status: :disabled)
      host = Host.new(@valid_attr)
      expect(host).to be_valid
      @valid_attr.update(status: :running)
      host = Host.new(@valid_attr)
      expect(host).not_to be_valid
    end

    it "cannot change when submitted runs exist" do
      host = FactoryBot.create(:host)
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0)
      ps = sim.parameter_sets.first
      run = ps.runs.create!(submitted_to: host)
      run.update_attribute(:status, :submitted)
      host.work_base_dir = "/path/to/another_dir"
      expect(host).not_to be_valid
    end

    it "can not be destroyed when submittable_runs or submitted_runs exist" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      run = sim.parameter_sets.first.runs.first
      host = run.submitted_to
      expect(host.destroy).to be_falsey
      expect(host.errors.full_messages).not_to be_empty
    end

    it "cannot be destroyed when submittable_analyses or submitted_analyses exist" do
      sim = FactoryBot.create(:simulator,
        parameter_sets_count: 1, runs_count: 1,
        analyzers_count: 1
        )
      run = sim.parameter_sets.first.runs.first
      run.update_attribute(:status, :finished)
      azr = sim.analyzers.first
      host = azr.executable_on.first
      run.analyses.create(analyzer: azr, submitted_to: host)
      expect(host.destroy).to be_falsey
      expect(host.errors.full_messages).not_to be_empty
    end

    it "can be destroyed when neither submittable_runs nor submitted_runs exist" do
      sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 1)
      run = sim.parameter_sets.first.runs.first
      run.update_attribute(:status, :finished)
      host = run.submitted_to
      expect(host.destroy).to be_truthy
      expect(host.errors.full_messages).to be_empty
    end
  end

  describe ".find_by_name" do

    it "returns the host with the given name" do
      h = FactoryBot.create(:host)
      found = Host.find_by_name(h.name)
      expect(h).to eq found
    end

    it "raises an exception when the host is not found" do
      expect {
        Host.find_by_name("do_not_exist")
      }.to raise_error("Host do_not_exist is not found")
    end
  end

  describe "#connected?" do

    before(:each) do
      @host = FactoryBot.create(:localhost)
    end

    it "returns true if ssh connection established" do
      expect(@host.connected?).to be_truthy
    end

    it "returns false when name is invalid" do
      @host.name = "INVALID_NAME"
      expect(@host.connected?).to be_falsey
    end
  end

  describe "#status" do

    before(:each) do
      @host = FactoryBot.create(:localhost)
    end

    it "returns status of hosts" do
      skip "not yet implemented"
    end
  end

  describe "#submittable_runs" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 2, runs_count: 0)
      @host = FactoryBot.create(:host)
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
      expect(@host.submittable_runs).to be_a(Mongoid::Criteria)
    end

    it "returns runs whose status is created and submitted_to is self" do
      expect(@host.submittable_runs.size).to eq 6
    end

    it "returns runs whose HostGroup includes self" do
      hg = FactoryBot.create(:host_group, hosts: [@host])
      new_run = @sim.parameter_sets.first.runs.create!(host_group: hg)
      expect( @host.submittable_runs.size ).to eq 7
      expect( @host.submittable_runs.include?(new_run) ).to be_truthy
    end

    it "does not return runs whose submitted_to is not self" do
      another_host = FactoryBot.create(:host)
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

      expect(@host.submittable_runs.size).to eq 8
      @host.submittable_runs.each do |run|
        expect(run.submitted_to).not_to eq another_host
      end
    end
  end

  describe "#submitted_runs" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1, runs_count: 0)
      @host = FactoryBot.create(:host)
      host2 = FactoryBot.create(:host)
      ps = @sim.parameter_sets.first
      FactoryBot.create_list(:run, 3,
                              parameter_set: ps, status: :submitted, submitted_to: @host)
      FactoryBot.create_list(:run, 1,
                              parameter_set: ps, status: :running, submitted_to: @host)
      FactoryBot.create_list(:run, 1,
                              parameter_set: ps, status: :finished, submitted_to: @host)
      FactoryBot.create_list(:run, 2,
                              parameter_set: ps, status: :submitted, submitted_to: host2)
    end

    it "returns a query" do
      expect(@host.submitted_runs).to be_a(Mongoid::Criteria)
    end

    it "returns runs whose status is 'submitted' or 'running', and 'submitted_to' is the host" do
      expect(@host.submitted_runs.size).to eq 4
    end
  end

  describe "#runs_status_count" do

    before(:each) do
      @sim = FactoryBot.create(:simulator,
                                parameter_sets_count: 1, runs_count: 0)
      @host = FactoryBot.create(:host)
      host2 = FactoryBot.create(:host)
      ps = @sim.parameter_sets.first
      FactoryBot.create_list(:run, 5,
                              parameter_set: ps, status: :created, submitted_to: @host)
      FactoryBot.create_list(:run, 4,
                              parameter_set: ps, status: :submitted, submitted_to: @host)
      FactoryBot.create_list(:run, 3,
                              parameter_set: ps, status: :running, submitted_to: @host)
      FactoryBot.create_list(:run, 2,
                              parameter_set: ps, status: :finished, submitted_to: @host)
      FactoryBot.create_list(:run, 1,
                              parameter_set: ps, status: :failed, submitted_to: @host)
      FactoryBot.create_list(:run, 2,
                              parameter_set: ps, status: :submitted, submitted_to: host2)
    end

    it "returns the number of runs for each status" do
      expected = {created: 5, submitted: 4, running: 3, finished: 2, failed: 1}
      expect(@host.runs_status_count).to eq expected
    end
  end

  describe "#default_host_parameters" do

    it "returns default values of host parameters" do
      hpd1 = HostParameterDefinition.new(key: "hp1", default: "foo")
      hpd2 = HostParameterDefinition.new(key: "hp2", default: "bar")
      host = FactoryBot.create(:host, host_parameter_definitions: [hpd1,hpd2] )
      expect( host.default_host_parameters ).to eq( {"hp1"=>"foo","hp2"=>"bar"} )
    end
  end

  describe "registering host_parameter_definitions" do

    it "gets host parameters by invoking 'get_host_parameters' when host status is changed into :enabled" do
      @host = FactoryBot.create(:localhost)
      @host.update_attribute(:status, :disabled)
      expect(@host).to receive(:get_host_parameters)
      @host.status = :enabled
      @host.save!
    end

    it "parse output of 'xsub -t' and set it to host_parameter_definitions" do
      hp = {"parameters" => {"foo" => {"default"=>1}, "bar" => {"default"=>"abc"} } }
      expect(SSHUtil).to receive(:execute2).and_return([hp.to_json,"",0])
      @host = FactoryBot.create(:localhost)
      expect(@host.host_parameter_definitions.size).to eq 2
      expect(@host.host_parameter_definitions[0].key).to eq "foo"
      expect(@host.host_parameter_definitions[0].default).to eq "1"
    end

    it "ignores 'mpi_procs' and 'omp_threads' parameters when setting host_parameter_definitions" do
      hp = {"parameters" => {"mpi_procs" => {"default"=>1}, "omp_threads" => {"default"=>"1"} } }
      expect(SSHUtil).to receive(:execute2).and_return([hp.to_json,"",0])
      @host = FactoryBot.create(:localhost)
      expect(@host.host_parameter_definitions).to be_empty
    end

    it "'xsub' command fails, validation fails" do
      expect(SSHUtil).to receive(:execute2).and_return(["{invalid:...","",0])
      @host = FactoryBot.build(:localhost)
      expect(@host).to_not be_valid
    end

    it "'xsub' command fails, write message to logger" do
      skip "when xsub command fails, write message to logger"
    end
  end

  describe "'position' field" do

    before(:each) do
      FactoryBot.create_list(:host, 2)
    end

    it "the largest number within existing hosts is assigned when created" do
      allow_any_instance_of(Host).to receive(:get_host_parameters) do
        []
      end
      expect(Host.create!(name: 'h1').position).to eq 2
      expect(Host.all.map(&:position)).to match_array([0,1,2])
    end
  end

  describe "#destroy" do

    before(:each) do
      @host = FactoryBot.create(:host_with_parameters)
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0, finished_runs_count: 1)
      @sim.executable_on.destroy
      @sim.executable_on << @host
      @sim.save
    end

    it "delete default_host_parameters from executable simulators" do
      host_id = @host.id.to_s
      host_parameters = @sim.get_default_host_parameter(@host)
      expect {
        @host.destroy
      }.to change { @sim.reload.default_host_parameters[host_id] }.from(host_parameters).to(nil)
    end

    it "delete default_mpi_procs from executable simulators" do
      host_id = @host.id.to_s
      @sim.update_attribute(:default_mpi_procs, {host_id => 4})
      @sim.get_default_host_parameter(@host)
      expect {
        @host.destroy
      }.to change { @sim.reload.default_mpi_procs[host_id] }.from(4).to(nil)
    end

    it "delete default_omp_threads from executable simulators" do
      host_id = @host.id.to_s
      @sim.update_attribute(:default_omp_threads, {host_id => 4})
      @sim.get_default_host_parameter(@host)
      expect {
        @host.destroy
      }.to change { @sim.reload.default_omp_threads[host_id] }.from(4).to(nil)
    end
  end

  context "when status is updated to :disabled" do

    before(:each) do
      @host = FactoryBot.create(:host_with_parameters)
      @sim = FactoryBot.create(:simulator, parameter_sets_count: 1, runs_count: 0, finished_runs_count: 1)
      @sim.executable_on.destroy
      @sim.executable_on << @host
      @sim.save
    end

    it "delete default_host_parameters of executable simulators" do
      host_parameters = @sim.get_default_host_parameter(@host)
      expect(@host.status).to eq :enabled
      expect {
        @host.status = :disabled
        @host.save
      }.to change { @sim.reload.default_host_parameters[@host.id.to_s] }.from(host_parameters).to(nil)
    end

    it "delete default_mpi_procs from executable simulators" do
      host_id = @host.id.to_s
      @sim.update_attribute(:default_mpi_procs, {host_id => 4})
      @sim.get_default_host_parameter(@host)
      expect {
        @host.status = :disabled
        @host.save
      }.to change { @sim.reload.default_mpi_procs[host_id] }.from(4).to(nil)
    end

    it "delete default_omp_threads from executable simulators" do
      host_id = @host.id.to_s
      @sim.update_attribute(:default_omp_threads, {host_id => 4})
      @sim.get_default_host_parameter(@host)
      expect {
        @host.status = :disabled
        @host.save
      }.to change { @sim.reload.default_omp_threads[host_id] }.from(4).to(nil)
    end
  end
end
