require 'open3'
require 'securerandom'

module SSHUtil

  class CommandTimeoutError < StandardError; end

  class ShellSession

    # safeguard against a hung remote command blocking the worker forever;
    # long enough for a legitimately slow pre-process script
    DEFAULT_COMMAND_TIMEOUT = 3600 # seconds

    attr_reader :token

    def initialize(channel, token:, command_timeout: DEFAULT_COMMAND_TIMEOUT)
      @ch = channel
      @token = token
      @pattern = /#{Regexp.escape(token)} (\d+)$/
      @command_timeout = command_timeout
      @deadline = nil
    end

    def exec!(command)
      exec2!(command)[:stdout]
    end

    def exec2!(command)
      send_command(command)
      Fiber.yield
    end

    def send_command(command)
      @deadline = Time.now + @command_timeout if @command_timeout
      @ch.send_data("#{command}\necho '#{@token}' $?\n")
    end

    def command_finished!
      @deadline = nil
    end

    def deadline_exceeded?
      !@deadline.nil? && Time.now > @deadline
    end

    def match_finished_token(buffer)
      @pattern.match(buffer)
    end

    def self.start(session, shell: "bash -l", logger: nil, command_timeout: DEFAULT_COMMAND_TIMEOUT)
      # a random token prevents command output from being mistaken for the marker
      token = "OACIS_CMD_DONE_#{SecureRandom.hex(8)}"
      sh = nil
      channel = session.open_channel do |ch|
        ch.exec(shell) do |ch2, success|
          raise "failed to open shell" unless success

          sh = ShellSession.new(ch2, token: token, command_timeout: command_timeout)
          # Set the terminal type
          sh.send_command("export TERM=vt100")

          f = Fiber.new do
            yield sh
            ch2.send_data("exit\n")
          end

          output = {stdout: "", stderr: ""}

          ch2.on_data do |c,data|
            logger&.debug "o: #{data.chomp.scrub}"
            # accumulate the output in a buffer; the completion token may be
            # split across data chunks
            output[:stdout] += data
            if m = sh.match_finished_token(output[:stdout])
              rc = m[1].to_i
              logger&.debug "rc: #{rc}"
              o = { stdout: m.pre_match, stderr: output[:stderr], rc: rc }
              output = {stdout: "", stderr: ""}
              sh.command_finished!
              f.resume o
            end
          end

          ch2.on_extended_data do |c,type,data|
            logger&.debug "e: #{data.chomp.scrub}"
            output[:stderr] += data
          end
        end
      end

      if session.respond_to?(:loop)  # Net::SSH
        session.loop(0.5) { channel.active? && !(sh && sh.deadline_exceeded?) }
        if sh && sh.deadline_exceeded?
          channel.close rescue nil
          raise CommandTimeoutError, "remote command did not finish within #{command_timeout} seconds"
        end
      else  # PopenSSH
        begin
          channel.wait(timeout: command_timeout)
        rescue Timeout::Error
          raise CommandTimeoutError, "remote command did not finish within #{command_timeout} seconds"
        end
      end
    end
  end

  # Escape a remote path for the remote shell, keeping a leading '~' intact
  # so that tilde expansion works (work_base_dir defaults to '~/oacis_work')
  def self.escape_remote_path(path)
    s = path.to_s
    if s == "~"
      s
    elsif s.start_with?("~/")
      "~/" + Shellwords.escape(s[2..])
    else
      Shellwords.escape(s)
    end
  end

  def self.download_file(hostname, remote_path, local_path)
    cmd = "scp -Bqr '#{hostname}:#{remote_path}' #{local_path}"
    _out, err, status = Open3.capture3(cmd)
    raise "'#{cmd}' failed with #{status.exitstatus}: #{err.chomp}" unless status.success?
  end

  def self.download_directory(hostname, remote_path, local_path)
    FileUtils.mkdir_p(local_path)
    cmd = "scp -Bqr '#{hostname}:#{remote_path}/*' #{local_path}"
    _out, err, status = Open3.capture3(cmd)
    raise "'#{cmd}' failed with #{status.exitstatus}: #{err.chomp}" unless status.success?
  end

  def self.download_recursive_if_exist(sh, hostname, remote_path, local_path)
    if directory?(sh, remote_path)
      out = sh.exec!("ls #{escape_remote_path(remote_path)}/")  # checking empty directory
      if out.chomp.empty?
        FileUtils.mkdir_p(local_path)
      else
        download_directory(hostname, remote_path, local_path)
      end
      :directory
    elsif file?(sh, remote_path)
      download_file(hostname, remote_path, local_path)
      :file
    else
      nil
    end
  end

  def self.upload(hostname, local_path, remote_path)
    cmd = "scp -Bqr #{Shellwords.escape(local_path.to_s)} '#{hostname}:#{remote_path}'"
    if File.directory?(local_path)
      cmd = "scp -Bqr #{Shellwords.escape(local_path.to_s)}/ '#{hostname}:#{remote_path}'"
    end
    _out, err, status = Open3.capture3(cmd)
    raise "'#{cmd}' failed with #{status.exitstatus}: #{err.chomp}" unless status.success?
  end

  def self.rm_r(sh, remote_paths)
    remote_paths = [remote_paths] unless remote_paths.is_a?(Array)
    escaped = remote_paths.map {|p| escape_remote_path(p) }
    sh.exec!("rm -rf #{escaped.join(' ')}")
  end

  def self.uname(sh)
    sh.exec!("uname").chomp
  end

  def self.execute(sh, command)
    sh.exec!(command)
  end

  def self.execute2(sh, command)
    out = sh.exec2!(command)
    [out[:stdout], out[:stderr], out[:rc]]
  end

  def self.write_remote_file(hostname, remote_path, content)
    Tempfile.create("") do |f|
      f.print(content)
      f.flush
      upload(hostname, f.path, remote_path)
    end
  end

  def self.file?(sh, remote_path)
    _out,_err,rc = execute2(sh, "test -f #{escape_remote_path(remote_path)}")
    rc == 0
  end

  def self.directory?(sh, remote_path)
    _out,_err,rc = execute2(sh, "test -d #{escape_remote_path(remote_path)}")
    rc == 0
  end

  def self.exist?(sh, remote_path)
    _out,_err,rc = execute2(sh, "test -e #{escape_remote_path(remote_path)}")
    rc == 0
  end
end
