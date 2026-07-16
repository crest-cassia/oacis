require 'spec_helper'

describe SSHUtil::ShellSession do

  # Emulates an SSH channel: responds to each command sent by ShellSession
  # with the chunks returned by the responder block.
  class FakeShellChannel
    def initialize(&responder)
      @responder = responder # (command_data, token) -> array of data chunks
      @pending = []
      @active = true
    end

    def exec(shell)
      yield self, true
    end

    def send_data(data)
      @pending << data
    end

    def on_data(&block); @on_data = block; end
    def on_extended_data(&block); end

    def active?; @active; end
    def close; @active = false; end

    def wait(timeout: nil)
      while @pending.any?
        data = @pending.shift
        token = data[/echo '([^']+)' \$\?/, 1]
        next if token.nil? # e.g. "exit\n"
        @responder.call(data, token).each do |chunk|
          @on_data.call(self, chunk)
        end
      end
    end
  end

  # PopenSSH-like session: no #loop, the channel drives the interaction in #wait
  class FakeShellSession
    def initialize(channel); @channel = channel; end

    def open_channel
      yield @channel
      @channel
    end
  end

  # Net::SSH-like session with #loop; used for the timeout test
  class FakeLoopShellSession
    def initialize(channel); @channel = channel; end

    def open_channel
      yield @channel
      @channel
    end

    def loop(wait = nil)
      while yield
        sleep 0.01
      end
    end
  end

  def start_and_exec(responder, command)
    channel = FakeShellChannel.new(&responder)
    session = FakeShellSession.new(channel)
    result = nil
    SSHUtil::ShellSession.start(session) do |sh|
      result = sh.exec2!(command)
    end
    result
  end

  it "returns stdout and rc of the executed command" do
    responder = lambda do |data, token|
      if data.include?("export TERM")
        ["#{token} 0\n"]
      else
        ["hello\n#{token} 0\n"]
      end
    end
    result = start_and_exec(responder, "echo hello")
    expect(result[:stdout]).to eq "hello\n"
    expect(result[:rc]).to eq 0
  end

  it "returns a non-zero rc" do
    responder = lambda do |data, token|
      if data.include?("export TERM")
        ["#{token} 0\n"]
      else
        ["oops\n#{token} 2\n"]
      end
    end
    expect(start_and_exec(responder, "false")[:rc]).to eq 2
  end

  it "detects the completion token even when it is split across data chunks" do
    responder = lambda do |data, token|
      if data.include?("export TERM")
        ["#{token} 0\n"]
      else
        # the token arrives split into two chunks
        ["hello\n" + token[0..4], token[5..] + " 0\n"]
      end
    end
    result = start_and_exec(responder, "echo hello")
    expect(result[:stdout]).to eq "hello\n"
    expect(result[:rc]).to eq 0
  end

  it "raises CommandTimeoutError when the remote command does not finish in time" do
    channel = FakeShellChannel.new {|data, token| [] } # never responds
    session = FakeLoopShellSession.new(channel)
    expect {
      SSHUtil::ShellSession.start(session, command_timeout: 0.1) do |sh|
        sh.exec!("sleep 100")
      end
    }.to raise_error(SSHUtil::CommandTimeoutError)
    expect(channel.active?).to be_falsey
  end

  describe "command timeout with a real SSH connection to localhost" do

    # the command keeps producing output at intervals shorter than the
    # timeout: the deadline must be absolute, not an inactivity timeout
    STREAMING_COMMAND = "while true; do echo tick; sleep 0.2; done"

    it "raises CommandTimeoutError with the Net::SSH backend" do
      Net::SSH.start('localhost', ENV['USER'], non_interactive: true, timeout: 1) do |ssh|
        expect {
          SSHUtil::ShellSession.start(ssh, command_timeout: 2) do |sh|
            sh.exec!(STREAMING_COMMAND)
          end
        }.to raise_error(SSHUtil::CommandTimeoutError)
      end
    end

    it "raises CommandTimeoutError with the PopenSSH backend" do
      PopenSSH.start('localhost', ENV['USER'], non_interactive: true, timeout: 1) do |ssh|
        expect {
          SSHUtil::ShellSession.start(ssh, command_timeout: 2) do |sh|
            sh.exec!(STREAMING_COMMAND)
          end
        }.to raise_error(SSHUtil::CommandTimeoutError)
      end
    end
  end
end
