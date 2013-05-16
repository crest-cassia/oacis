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
      valid_attr = {
        name: "localhost",
        hostname: "localhost",
        user: ENV['USER']
      }
      @host = Host.new(valid_attr)
      @temp_dir = Pathname.new('__temp__')
      FileUtils.mkdir_p(@temp_dir)
      FileUtils.touch(@temp_dir.join('__abc__'))
      @temp_dir2 = Pathname.new('__temp2__')
    end

    after(:each) do
      FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
      FileUtils.rm_r(@temp_dir2) if File.directory?(@temp_dir2)
    end

    it "downloads files to the specified path and return the paths" do
      @host.download(@temp_dir.expand_path, @temp_dir2)
      File.directory?(@temp_dir2).should be_true
      File.exist?(@temp_dir2.join('__abc__')).should be_true
    end

    it "raises an exception if connection to the remote host failed" do
      @host.hostname = 'INVALID.HOSTNAME'
      expect {
        @host.download(@temp_dir.expand_path, @temp_dir2)
      }.to raise_error SocketError
      File.directory?(@temp_dir2).should_not be_true
    end
  end
end
