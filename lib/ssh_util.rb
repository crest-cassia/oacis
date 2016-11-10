module SSHUtil

  def self.download(ssh, remote_path, local_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    sftp = ssh.sftp
    sftp.connect! if sftp.closed?
    sftp.download!(rpath, local_path.to_s) # .to_s is necessary for Ruby2.1.0. See https://github.com/crest-cassia/cassia/pull/124
  end

  def self.download_recursive(ssh, remote_path, local_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    is_dir = directory?(ssh, rpath)
    sftp = ssh.sftp
    sftp.connect! if sftp.closed?
    sftp.download!(rpath, local_path.to_s, {recursive: is_dir}) # .to_s is necessary for Ruby2.1.0. See https://github.com/crest-cassia/cassia/pull/124
  end

  def self.download_recursive_if_exist(ssh, remote_path, local_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    s = stat(ssh, rpath)
    if s
      sftp = ssh.sftp
      sftp.connect! if sftp.closed?
      sftp.download!(rpath, local_path.to_s, {recursive: (s==:directory)})
    end
  end

  def self.upload(ssh, local_path, remote_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    is_dir = File.directory?(local_path)
    sftp = ssh.sftp
    sftp.connect! if sftp.closed?
    if is_dir
      sftp.upload!(local_path.to_s, rpath, mkdir: true)
    else
      sftp.upload!(local_path.to_s, rpath.to_s)
    end
  end

  def self.rm_r(ssh, remote_paths)
    remote_paths = [remote_paths] unless remote_paths.is_a?(Array)
    rpaths = remote_paths.to_a.map {|rpath| expand_remote_home_path(ssh,rpath) }
    ssh.exec!("rm -rf #{rpaths.join(' ')}")
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

  def self.stat(ssh, remote_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    begin
      sftp = ssh.sftp
      sftp.connect! if sftp.closed?
      sftp.stat!(rpath) do |response|
        if response.ok?
          return (response[:attrs].directory? ? :directory : :file)
        end
      end
    rescue Net::SFTP::StatusException => ex
      raise ex unless ex.code == 2  # no such file
    end
    return nil
  end

  def self.exist?(ssh, remote_path)
    s = stat(ssh, remote_path)
    s == :directory || s == :file
  end

  def self.directory?(ssh, remote_path)
    stat(ssh, remote_path) == :directory
  end

  private
  # Net::SSH and Net::SFTP can't interpret '~' as a home directory
  # a relative path is recognized as a relative path from home directory
  # so replace '~' with '.' in this method
  def self.expand_remote_home_path(ssh, path)
    home = ssh.instance_variable_get(:@home_dir_cache)
    unless home
      home = ssh.exec!("echo $HOME").chomp
      ssh.instance_variable_set(:@home_dir_cache, home)
    end
    Pathname.new( path.to_s.sub(/^~/, home) )
  end
end
