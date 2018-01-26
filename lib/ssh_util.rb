module SSHUtil

  def self.download_file(hostname, remote_path, local_path)
    cmd = "rsync -aq #{hostname}:#{remote_path} #{local_path} 2> /dev/null"
    system(cmd)
    raise "'#{cmd}' failed : #{$?.to_i}" unless $?.to_i == 0
  end

  def self.download_directory(hostname, remote_path, local_path)
    cmd = "rsync -aq #{hostname}:#{remote_path}/ #{local_path} 2> /dev/null"
    system(cmd)
    raise "'#{cmd}' failed : #{$?.to_i}" unless $?.to_i == 0
  end

  def self.download_recursive_if_exist(ssh, hostname, remote_path, local_path)
    s = stat(ssh, remote_path)
    if s == :directory
      download_directory(hostname, remote_path, local_path)
    elsif s == :file
      download_file(hostname, remote_path, local_path)
    end
    s
  end

  def self.upload(hostname, local_path, remote_path)
    cmd = "rsync -aq #{local_path} #{hostname}:#{remote_path}"
    if File.directory?(local_path)
      cmd = "rsync -aq #{local_path}/ #{hostname}:#{remote_path}"
    end
    system(cmd)
    raise "'#{cmd}' failed : #{$?.to_i}" unless $?.to_i == 0
  end

  def self.rm_r(ssh, remote_paths)
    remote_paths = [remote_paths] unless remote_paths.is_a?(Array)
    ssh.exec!("rm -rf #{remote_paths.join(' ')}")
  end

  def self.uname(ssh)
    ssh.exec!("uname").chomp
  end

  def self.execute(ssh, command)
    ssh.exec!(command)
  end

  def self.execute_in_background(ssh, command)
    # NOTE: must be redirected to a file. Otherwise, ssh.exec! does not return immediately
    # http://stackoverflow.com/questions/29142/getting-ssh-to-execute-a-command-in-the-background-on-target-machine
    # a semi-colon is necessary at the back of the command
    ssh.exec!("{ #{command.sub(/;^/,'')}; } > /dev/null 2>&1 < /dev/null &")
  end

  def self.execute2(ssh, command)
    stdout_data = ""
    stderr_data = ""
    exit_code = nil
    exit_signal = nil
    # must close sftp channel, otherwise it hangs
    ssh.sftp.close_channel unless ssh.sftp.closed?

    ssh.open_channel do |channel|
      channel.exec(command) do |ch, success|
        unless success
          abort "FAILED: couldn't execute command (ssh.channel.exec)"
        end
        channel.on_data do |ch,data|
          stdout_data+=data
        end

        channel.on_extended_data do |ch,type,data|
          stderr_data+=data
        end

        channel.on_request("exit-status") do |ch,data|
          exit_code = data.read_long
        end

        channel.on_request("exit-signal") do |ch, data|
          exit_signal = data.read_long
        end
      end
    end
    ssh.loop
    [stdout_data, stderr_data, exit_code, exit_signal]
  end

  def self.write_remote_file(hostname, remote_path, content)
    Tempfile.create("") do |f|
      f.print(content)
      f.flush
      upload(hostname, f.path, remote_path)
    end
  end

  def self.stat(ssh, remote_path)
    out = execute(ssh, "{test -d #{remote_path} && echo d} || {test -f #{remote_path} && echo f}")
    if out.chomp == 'd'
      :directory
    elsif out.chomp == 'f'
      :file
    else
      nil
    end
  end

  def self.exist?(ssh, remote_path)
    s = stat(ssh, remote_path)
    s == :directory || s == :file
  end

  def self.directory?(ssh, remote_path)
    stat(ssh, remote_path) == :directory
  end
end
