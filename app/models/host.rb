class Host
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :hostname, type: String
  field :user, type: String
  field :port, type: Integer, default: 22
  field :ssh_key, type: String, default: '~/.ssh/id_rsa'
  field :show_status_command, type: String, default: 'ps au'
  field :submission_command, type: String, default: 'nohup'
  field :work_base_dir, type: String, default: '~'
  field :simulator_base_dir, type: String, default: '~'

  validates :name, presence: true, uniqueness: true, length: {minimum: 1}
  validates :hostname, presence: true, format: {with: /^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$/}
  # See http://stackoverflow.com/questions/1418423/the-hostname-regex for the regexp of the hsotname

  validates :user, presence: true, format: {with: /^[A-Za-z0-9]+(?:[ _-][A-Za-z0-9]+)*$/}
  # See http://stackoverflow.com/questions/1221985/how-to-validate-a-user-name-with-regex

  validates :port, numericality: {greater_than_or_equal_to: 1, less_than: 65536}

  CONNECTION_EXCEPTIONS = [
    Errno::ECONNREFUSED,
    Errno::ENETUNREACH,
    SocketError,
    Net::SSH::Exception,
    OpenSSL::PKey::RSAError
  ]

  public
  # return true if connection established, return true
  # return false otherwise
  # connection exception is stored in @connection_error
  def connected?
    Net::SSH.start(hostname, user, password: "")  # disabled password authentication
  rescue *CONNECTION_EXCEPTIONS => ex
    @connection_error = ex
    return false
  else
    return true
  end

  attr_reader :connection_error

  def download(remote_path, local_path)
    raise "Not an absolute path: #{remote_path}" unless Pathname.new(remote_path).absolute?
    start_sftp do |sftp|
      sftp.download!(remote_path, local_path, recursive: true)
    end
  end

  def rm_r(remote_path)
    raise "Not an abosolute path:#{remote_path}" unless Pathname.new(remote_path).absolute?
    start_ssh do |ssh|
      ssh.exec!("rm -r #{remote_path}")
    end
  end

  def uname
    uname = nil
    start_ssh do |ssh|
      uname = ssh.exec!("uname").chomp
    end
    return uname
  end

  def status
    ret = nil
    start_ssh do |ssh|
      unless show_status_command.blank?
        ret = ssh.exec!(show_status_command)
      else
        uname = ssh.exec!("uname").chomp
        cmd = "top -b -n 1"
        cmd = "top -l 1 -o cpu" if uname =~ /Darwin/
        cmd += " | head -n 20"
        ret = ssh.exec!(cmd)
      end
    end
    return ret
  end

  private
  def start_ssh
    Net::SSH.start(hostname, user, password: "", timeout: 1) do |ssh|
      yield ssh
    end
  end

  def start_sftp
    Net::SFTP.start(hostname, user, password: "", timeout: 1) do |sftp|
      yield sftp
    end
  end
end
