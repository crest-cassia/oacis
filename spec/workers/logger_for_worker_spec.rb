require 'spec_helper'

describe LoggerForWorker do

  before(:each) do
    @temp_dir = Pathname.new('__temp_logger__')
    FileUtils.mkdir_p(@temp_dir)
    @log_path = @temp_dir.join('worker.log')
    @logger = LoggerForWorker.new(:service, @log_path, 7)
  end

  after(:each) do
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  it "creates a WorkerLog record for info and above" do
    expect {
      @logger.info("recorded message")
    }.to change { WorkerLog.count }.by(1)
  end

  it "does not create a WorkerLog record for debug" do
    expect {
      @logger.debug("debug message")
    }.to_not change { WorkerLog.count }
  end

  context "when WorkerLog cannot be saved (e.g. MongoDB is down)" do

    before(:each) do
      allow(WorkerLog).to receive(:create).and_raise("mongodb is down")
    end

    it "does not raise and still writes to the log file" do
      expect {
        @logger.error("error while db is down")
      }.to_not raise_error
      expect(File.read(@log_path)).to include("error while db is down")
    end
  end

  context "when ActionCable broadcast fails (e.g. Redis is down)" do

    before(:each) do
      allow(WorkerLogChannel).to receive(:broadcast_to).and_raise("redis is down")
    end

    it "does not raise and still writes to the log file" do
      expect {
        @logger.info("info while cable is down")
      }.to_not raise_error
      expect(File.read(@log_path)).to include("info while cable is down")
    end
  end
end
