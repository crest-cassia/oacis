require 'spec_helper'

describe HostPolling do

  before(:each) do
    @task_class = Class.new { extend HostPolling }
    @logger = Logger.new( File.open('/dev/null','w') )
    Worker.term_received = false
  end

  after(:each) do
    Worker.term_received = false
  end

  describe ".each_host_to_poll" do

    it "yields each enabled host" do
      host1 = FactoryBot.create(:host)
      host2 = FactoryBot.create(:host)
      FactoryBot.create(:host, status: :disabled)
      yielded = []
      @task_class.each_host_to_poll(@logger) {|host| yielded << host.id }
      expect(yielded).to match_array [host1.id, host2.id]
    end

    it "continues with the remaining hosts when processing of one host fails" do
      host1 = FactoryBot.create(:host)
      host2 = FactoryBot.create(:host)
      yielded = []
      expect {
        @task_class.each_host_to_poll(@logger) do |host|
          yielded << host.id
          raise "error" if host.id == host1.id
        end
      }.to_not raise_error
      expect(yielded).to match_array [host1.id, host2.id]
    end

    it "skips a host until its polling interval has passed" do
      FactoryBot.create(:host)
      count = 0
      @task_class.each_host_to_poll(@logger) {|host| count += 1 }
      @task_class.each_host_to_poll(@logger) {|host| count += 1 }
      expect(count).to eq 1
    end

    it "does not yield hosts after TERM is received" do
      FactoryBot.create(:host)
      Worker.term_received = true
      yielded = false
      @task_class.each_host_to_poll(@logger) {|host| yielded = true }
      expect(yielded).to be_falsey
    end
  end
end
