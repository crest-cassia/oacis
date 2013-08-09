module SSHUtil

  def self.download(ssh, remote_path, local_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    ssh.sftp.download!(rpath, local_path)
  end

  def self.download_recursive(ssh, remote_path, local_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    ssh.sftp.download!(rpath, local_path, {recursive: true})
  end

  def self.upload(ssh, local_path, remote_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    ssh.sftp.upload!(local_path.to_s, remote_path)
  end

  def self.rm_r(ssh, remote_path)
    rpath = expand_remote_home_path(ssh, remote_path)
    ssh.exec!("rm -r #{rpath}")
  end

  def self.uname(ssh)
    ssh.exec!("uname").chomp
  end

  def self.execute(ssh, command)
    ssh.exec!(command).chomp
  end

  def self.execute_in_background(ssh, command)
    # NOTE: must be redirected to a file. Otherwise, ssh.exec! does not return immediately
    # http://stackoverflow.com/questions/29142/getting-ssh-to-execute-a-command-in-the-background-on-target-machine
    ssh.exec!("{ #{command} } > /dev/null 2>&1 < /dev/null &")
  end

  def self.write_remote_file(ssh, remote_path, content)
    rpath = expand_remote_home_path(ssh, remote_path)
    ssh.sftp.file.open(rpath, 'w') { |f|
      f.print content
    }
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