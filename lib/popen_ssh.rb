require 'open3'

module PopenSSH
  class ConnectionError < StandardError; end

  def self.start(host, user, **opts, &block)
    session = Session.new(host, user, opts)
    yield session if block
  end

  class Session
    attr_reader :host, :user, :opts

    def initialize(host, user, opts = {})
      @host = host
      @user = user
      @opts = opts
    end

    def open_channel(&block)
      channel = Channel.new(self, @opts)
      yield channel if block
      channel
    end
  end

  class Channel
    def initialize(session, opts = {})
      @session = session
      @opts = opts
      @logger = opts[:logger]
    end

    def exec(command, &block)
      args = ["ssh"]

      # Apply BatchMode for non-interactive SSH
      args += ["-o", "BatchMode=yes"] if @opts[:non_interactive]
      args += ["-l", @session.user] if @session.user
      args += [@session.host, "--"]
      args.concat(Shellwords.split(command))

      @logger&.debug("[PopenSSH] exec: #{args.join(' ')}")

      begin
        @stdin, @stdout, @stderr, @wait_thr = *Open3.popen3(*args)
      rescue => e
        raise PopenSSH::ConnectionError, "Failed to start ssh: #{e.class}: #{e.message}"
      end
      check_ssh_startup_failure!

      yield self, true if block
    end

    def check_ssh_startup_failure!
      # If the SSH process exited immediately, assume failure.
      timeout = @opts[:timeout] || 1
      if @wait_thr.join(timeout)
        exit_code = @wait_thr.value.exitstatus
        stderr_output = @stderr.read.to_s.strip
        raise PopenSSH::ConnectionError,
              "SSH exited immediately with status #{exit_code}: #{stderr_output}"
      end
    end

    def send_data(data)
      @stdin.write(data)
      @stdin.flush
    end

    def on_data(&block)
      @on_data_block = block
    end

    def on_extended_data(&block)
      @on_extended_data_block = block
    end

    def on_close(&block)
      @on_close_block = block
    end

    def wait(timeout: nil)
      ios = [@stdout, @stderr]
      timeout ||= @opts[:timeout]

      loop do
        ready = IO.select(ios, nil, nil, timeout)

        break unless ready

        ready[0].each do |io|
          begin
            data = io.read_nonblock(1024)
            case io
            when @stdout
              @on_data_block&.call(self, data)
            when @stderr
              @on_extended_data_block&.call(self, 1, data)
            end
          rescue IO::WaitReadable
            next
          rescue EOFError
            ios.delete(io)
            io.close
          end
        end

        break if ios.empty?
      end

      unless @wait_thr.join(timeout)
        Process.kill("TERM", @wait_thr.pid)
        raise Timeout::Error, "SSH process did not exit in time"
      end

      @on_close_block&.call
    end
  end
end
