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
        show_status_command: 'ps au',
        submission_command: 'nohup',
        work_base_dir: '~/__cm_work__',
        simulator_base_dir: '~'
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

    it "default of 'show_status_command is 'ps au'" do
      @valid_attr.delete(:show_status_command)
      Host.new(@valid_attr).show_status_command.should eq('ps au')
    end

    it "default of 'submission_command' is 'nohup'" do
      @valid_attr.delete(:submission_command)
      Host.new(@valid_attr).submission_command.should eq('nohup')
    end

    it "default of 'work_base_dir' is '~'" do
      @valid_attr.delete(:work_base_dir)
      Host.new(@valid_attr).work_base_dir.should eq('~')
    end

    it "default of 'simulator_base_dir' is '~'" do
      @valid_attr.delete(:simulator_base_dir)
      Host.new(@valid_attr).simulator_base_dir.should eq('~')
    end

    it "has timestamp fields" do
      host = Host.new(@valid_attr)
      host.should respond_to(:created_at)
      host.should respond_to(:updated_at)
    end
  end

  describe "#download" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      FileUtils.touch(@temp_dir.join('__abc__'))
      FileUtils.touch(@temp_dir.join('__def__'))
      @temp_dir2 = Pathname.new('__temp2__')
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
      FileUtils.rm_r(@temp_dir2) if File.directory?(@temp_dir2)
    end

    it "downloads files to the specified path and return the paths" do
      FileUtils.mkdir_p(@temp_dir2)
      @host.download(@temp_dir.expand_path, @temp_dir2)
      File.exist?(@temp_dir2.join('__abc__')).should be_true
      File.exist?(@temp_dir2.join('__def__')).should be_true
    end

    it "creates local directory if specified directory does not exist" do
      @host.download(@temp_dir.expand_path, @temp_dir2)
      File.directory?(@temp_dir2).should be_true
    end

    it "raises an exception if connection to the remote host failed" do
      @host.hostname = 'INVALID.HOSTNAME'
      expect {
        @host.download(@temp_dir.expand_path, @temp_dir2)
      }.to raise_error SocketError
      File.directory?(@temp_dir2).should_not be_true
    end
  end

  describe "#rm_r" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @temp_file = @temp_dir.join('__abc__')
      FileUtils.touch(@temp_file)
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "removes specified file" do
      @host.rm_r(@temp_file.expand_path)
      File.exist?(@temp_file).should be_false
    end

    it "removes specified directory even if the directory is not empty" do
      @host.rm_r(@temp_dir.expand_path)
      File.directory?(@temp_dir).should be_false
    end
  end

  describe "#uname" do

    before(:each) do
      @host = FactoryGirl.create(:localhost)
    end

    it "returns the result of 'uname' on the host" do
      @host.uname.should satisfy {|u|
        ["Linux", "Darwin"].include?(u)
      }
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
      @host.show_status_command = 'ps u'
    end

    it "returns status of hosts using show_status_command" do
      stat = @host.status
      stat.should match(/PID/)
      stat.should match(/COMMAND/)
      stat.should match(/TIME/)
    end

    it "calls top when show_status_command is not assigned" do
      @host.show_status_command = nil
      stat = @host.status
      stat.should match(/PID/)
      stat.should match(/COMMAND/)
      stat.should match(/TIME/)
    end
  end

  describe "#submittable_runs" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 2, runs_count: 3, finished_runs_count: 2)
      @host = FactoryGirl.create(:host)
    end

    it "returns a Mongoid::Critieria" do
      @host.submittable_runs.should be_a(Mongoid::Criteria)
    end

    it "returns runs whose status is created" do
      @host.submittable_runs.should have(6).items
    end
  end

  describe "#submitted_runs" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 0)
      @host = FactoryGirl.create(:host)
      host2 = FactoryGirl.create(:host)
      ps = @sim.parameter_sets.first
      FactoryGirl.create_list(:run, 2,
                              parameter_set: ps, status: :submitted, submitted_to: @host)
      FactoryGirl.create_list(:run, 3,
                              parameter_set: ps, status: :submitted, submitted_to: host2)
    end

    it "returns the number of jobs submittable to the host" do
      @host.submitted_runs.should be_a(Mongoid::Criteria)
    end

    it "returns runs whose status is 'submitted' and 'submitted_to' is the host" do
      @host.submitted_runs.should have(2).items
    end
  end

  describe "#submit" do

    before(:each) do
      @sim = FactoryGirl.create(:simulator,
                                parameter_sets_count: 1, runs_count: 2)
      @runs = @sim.parameter_sets.first.runs
      @host = FactoryGirl.create(:localhost)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      @host.work_base_dir = @temp_dir.expand_path
      @host.save!
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
    end

    it "creates a job script on the remote host" do
      @host.submit(@runs)
      Dir.glob( @temp_dir.join('*.sh') ).should have(2).items
    end

    it "returns paths of job scripts on remote host" do
      paths = @runs.map do |run|
        File.join(@host.work_base_dir, "#{run.id}.sh")
      end
      @host.submit(@runs).should eq paths
    end

    it "creates _input.json on the remote host if simulator support json_input" do
      @sim.support_input_json = true
      @sim.save!
      @host.submit(@runs)
      Dir.glob( @temp_dir.join('*_input.json') ).should have(2).items
    end

    it "submit job to queueing system on the remote host" do
      pending "test is not prepared yet"
    end
  end

  describe "#launch_worker_cmd" do

    pending "specification is subject to change"
  end
end
