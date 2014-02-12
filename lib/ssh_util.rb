module SSHUtil

  def self.download(ssh, remote_path, local_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    sftp = ssh.sftp
    sftp.connect! if sftp.closed?
    sftp.download!(rpath, local_path)
  end

  def self.download_recursive(ssh, remote_path, local_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    sftp = ssh.sftp
    sftp.connect! if sftp.closed?
    sftp.download!(rpath, local_path, {recursive: true})
  end

  def self.upload(ssh, local_path, remote_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    sftp = ssh.sftp
    sftp.connect! if sftp.closed?
    sftp.upload!(local_path.to_s, remote_path)
  end

  def self.rm_r(ssh, remote_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    ssh.exec!("rm -r #{rpath}")
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

  def self.write_remote_file(ssh, remote_path, content)
    rpath = expand_remote_home_path(ssh, remote_path)
    sftp = ssh.sftp
    sftp.connect! if sftp.closed?
    sftp.file.open(rpath, 'w') {|f|
      f.print content.gsub(/(\r\n|\r|\n)/, "\n")
    }
  end

  def self.exist?(ssh, remote_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    begin
      sftp = ssh.sftp
      sftp.connect! if sftp.closed?
      sftp.stat!(rpath) do |response|
        return true if response.ok?
      end
    rescue Net::SFTP::StatusException => ex
      raise ex unless ex.code == 2  # no such file
    end
    return false
  end

  def self.add_file_to_archive(ssh, remote_path, remote_archive)
    rpath = expand_remote_home_path(ssh, remote_path)
    cmd = "tar rf #{remote_archive} #{remote_path}"
    SSHUtil.comand(cmd)
  end

  private
  # Net::SSH and Net::SFTP can't interpret '~' as a home directory
  # a relative path is recognized as a relative path from home directory
  # so replace '~' with '.' in this method
  def self.expand_remote_home_path(ssh, path)
    home = ssh.exec!("echo $HOME").chomp
    Pathname.new( path.to_s.sub(/^~/, home) )
  end
end
