require 'spec_helper'

describe Worker do

  before(:each) do
    @temp_dir = Pathname.new('__temp_worker__')
    FileUtils.mkdir_p(@temp_dir)
    dummy = Class.new(Worker)
    dummy.const_set(:INTERVAL, 0)
    dummy.const_set(:WORKER_ID, :service)
    dummy.const_set(:WORKER_PID_FILE, @temp_dir.join("worker.pid"))
    dummy.const_set(:WORKER_LOG_FILE, @temp_dir.join("worker.log"))
    dummy.const_set(:WORKER_STDOUT_FILE, @temp_dir.join("worker_out.log"))
    stub_const("WorkerSpecDummy", dummy)
    Worker.term_received = false
  end

  after(:each) do
    Worker.term_received = false
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  describe "#start" do

    it "continues with the next task when a task raises an exception" do
      calls = []
      WorkerSpecDummy.const_set(:TASKS, [
        lambda {|logger| calls << :first; raise "task error" },
        lambda {|logger| calls << :second; Worker.term_received = true }
      ])
      WorkerSpecDummy.allocate.start([])
      expect(calls).to eq [:first, :second]
    end

    it "keeps running when both a task and the log persistence fail (e.g. MongoDB is down)" do
      allow(WorkerLog).to receive(:create).and_raise("mongodb is down")
      calls = []
      WorkerSpecDummy.const_set(:TASKS, [
        lambda {|logger| calls << :first; raise "task error" },
        lambda {|logger| calls << :second; Worker.term_received = true }
      ])
      WorkerSpecDummy.allocate.start([])
      expect(calls).to eq [:first, :second]
    end

    it "stops the loop when term_received is set" do
      count = 0
      WorkerSpecDummy.const_set(:TASKS, [
        lambda {|logger| count += 1; Worker.term_received = true }
      ])
      WorkerSpecDummy.allocate.start([])
      expect(count).to eq 1
    end
  end

  describe ".term_received?" do

    it "is shared between Worker and its subclasses" do
      Worker.term_received = true
      expect(WorkerSpecDummy.term_received?).to be_truthy
      Worker.term_received = false
      expect(WorkerSpecDummy.term_received?).to be_falsey
    end
  end
end
