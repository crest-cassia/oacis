require 'open3'

module PopenSSH
  def self.start(host, user, **opts, &block)
    session = Session.new(host, user, opts)
    yield session if block
  end

  class Session
    attr_reader :host, :user, :channel

    def initialize(host, user, opts = {})
      @host = host
      @user = user
      @opts = opts
    end

    def open_channel(&block)
      @channel = Channel.new(self, @opts)
      yield @channel if block
      @channel
    end

    def loop
      @channel.wait(timeout: @opts[:timeout])
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

      @stdin, @stdout, @stderr, @wait_thr = *Open3.popen3(*args)
      yield self, true if block
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
      start_time = Time.now

      loop do
        if timeout
          elapsed = Time.now - start_time
          raise Timeout::Error, "SSH command timed out (stdout/stderr)" if elapsed > timeout
        end

        remaining = timeout ? [timeout - (Time.now - start_time), 0.1].max : nil
        ready = IO.select(ios, nil, nil, remaining)

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
