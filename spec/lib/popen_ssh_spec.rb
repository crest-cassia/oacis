require 'spec_helper'

describe PopenSSH do
  let(:host) { 'example.com' }
  let(:user) { 'test_user' }
  let(:command) { 'echo Hello' }
  let(:logger) { double('Logger', debug: nil) }

  describe '.start' do
    it 'yields a session object' do
      PopenSSH.start(host, user) do |session|
        expect(session).to be_a(PopenSSH::Session)
        expect(session.host).to eq(host)
        expect(session.user).to eq(user)
      end
    end
  end

  describe PopenSSH::Session do
    let(:session) { PopenSSH::Session.new(host, user, logger: logger) }

    describe '#open_channel' do
      it 'yields a channel object' do
        session.open_channel do |channel|
          expect(channel).to be_a(PopenSSH::Channel)
        end
      end

      it 'returns a channel object' do
        channel = session.open_channel
        expect(channel).to be_a(PopenSSH::Channel)
      end
    end
  end

  describe PopenSSH::Channel do
    let(:session) { PopenSSH::Session.new(host, user, logger: logger, non_interactive: true) }
    let(:channel) { session.open_channel }

    describe '#exec' do
      it 'executes the command via SSH' do
        expect(Open3).to receive(:popen3).with('ssh', '-o', 'BatchMode=yes', '-l', user, host, '--', 'echo', 'Hello')
        channel.exec(command)
      end

      it 'logs the command execution' do
        expect(logger).to receive(:debug).with("[PopenSSH] exec: ssh -o BatchMode=yes -l test_user example.com -- echo Hello")
        channel.exec(command)
      end
    end

    describe '#send_data' do
      it 'writes data to stdin' do
        stdin = double('stdin', write: nil, flush: nil)
        allow(Open3).to receive(:popen3).and_return([stdin, nil, nil, nil])
        channel.exec(command)
        channel.send_data('test data')
        expect(stdin).to have_received(:write).with('test data')
        expect(stdin).to have_received(:flush)
      end
    end
  end
end