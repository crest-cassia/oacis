module SSHUtil

  class ShellSession

    TOKEN = "XXXDONEXXX"
    PATTERN = /XXXDONEXXX (\d+)$/

    def initialize(channel)
      @ch = channel
    end

    def exec!(command)
      @ch.send_data("#{command}\necho '#{TOKEN}' $?\n")
      o = Fiber.yield
      o[:stdout]
    end

    def exec2!(command)
      @ch.send_data("#{command}\necho '#{TOKEN}' $?\n")
      Fiber.yield
    end

    def self.start(session, shell:"bash -l", logger: nil)
      channel = session.open_channel do |ch|
        ch.exec(shell) do |ch2, success|
          raise "failed to open shell" unless success
          # Set the terminal type
          ch2.send_data "export TERM=vt100\necho '#{TOKEN}' $?\n"

          sh = ShellSession.new(ch2)
          f = Fiber.new do
            yield sh
            ch2.send_data("exit\n")
          end

          output = {stdout: "", stderr: "", rc: nil}

          ch2.on_data do |c,data|
            logger&.debug "o: #{data.chomp.scrub}"
            if data =~ PATTERN
              output[:stdout] += data.chomp.sub(PATTERN,'')
              rc = $1.to_i
              logger&.debug "rc: #{rc}"
              output[:rc] = rc
              o = output
              output = {stdout: "", stderr: "", rc: nil}
              f.resume o
            else
              output[:stdout] += data
            end
          end

          ch2.on_extended_data do |c,type,data|
            logger&.debug "e: #{data.chomp.scrub}"
            output[:stderr] += data
          end
        end
      end
      channel.wait
    end
  end

  def self.download_file(hostname, remote_path, local_path)
    cmd = "scp -Bqr '#{hostname}:#{remote_path}' #{local_path} 2> /dev/null"
    system(cmd)
    raise "'#{cmd}' failed : #{$?.to_i}" unless $?.to_i == 0
  end

  def self.download_directory(hostname, remote_path, local_path)
    FileUtils.mkdir_p(local_path)
    cmd = "scp -Bqr '#{hostname}:#{remote_path}/*' #{local_path} 2> /dev/null"
    system(cmd)
    raise "'#{cmd}' failed : #{$?.to_i}" unless $?.to_i == 0
  end

  def self.download_recursive_if_exist(sh, hostname, remote_path, local_path)
    if directory?(sh, remote_path)
      out = sh.exec!("ls #{remote_path}/")  # checking empty directory
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
    cmd = "scp -Bqr #{local_path} '#{hostname}:#{remote_path}'"
    if File.directory?(local_path)
      cmd = "scp -Bqr #{local_path}/ '#{hostname}:#{remote_path}'"
    end
    system(cmd)
    raise "'#{cmd}' failed : #{$?.to_i}" unless $?.to_i == 0
  end

  def self.rm_r(sh, remote_paths)
    remote_paths = [remote_paths] unless remote_paths.is_a?(Array)
    sh.exec!("rm -rf #{remote_paths.join(' ')}")
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
    _out,_err,rc = execute2(sh, "test -f #{remote_path}")
    rc == 0
  end

  def self.directory?(sh, remote_path)
    _out,_err,rc = execute2(sh, "test -d #{remote_path}")
    rc == 0
  end

  def self.exist?(sh, remote_path)
    _out,_err,rc = execute2(sh, "test -e #{remote_path}")
    rc == 0
  end
end
