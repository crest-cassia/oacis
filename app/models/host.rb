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
    start_ssh {|ssh| } # do nothing
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
        ps = ssh.exec!('ps au')
        ret = ps.lines.first
        ret += ps.lines.find_all {|l| l =~ /resque-\d/}.map{|l| l.chomp.strip }.join("\n")
        ret += "\n------------------\n\n"

        uname = ssh.exec!("uname").chomp
        cmd = "top -b -n 1"
        cmd = "top -l 1 -o cpu" if uname =~ /Darwin/
        cmd += " | head -n 20"
        ret += ssh.exec!(cmd)
      end
    end
    return ret
  end

  def launch_worker_cmd
    exe = './bin/rake'
    args = ['resque:workers',
            'QUEUE=simulator_queue',
            'LOAD_RAILS=false',
            'VERBOSE=1',
            "CM_HOST_ID=#{id}",
            "CM_WORK_DIR=#{work_base_dir}",
            "CM_SIMULATOR_DIR=#{simulator_base_dir}",
            'COUNT=1'
          ]
    return "nohup #{exe} #{args.join(' ')} &"
  end

  def submittable_runs
    Run.where(status: :created)
  end

  def submitted_runs
    Run.where(status: :submitted, submitted_to: self)
  end

  private
  def start_ssh
    Net::SSH.start(hostname, user, password: "", timeout: 1, keys: ssh_key, port: port) do |ssh|
      yield ssh
    end
  end

  def start_sftp
    Net::SFTP.start(hostname, user, password: "", timeout: 1, keys: ssh_key, port: port) do |sftp|
      yield sftp
    end
  end

  def ssh_exec!(ssh, command)
    # Originally submitted by 'flitzwald' over here: http://stackoverflow.com/a/3386375
    stdout_data = ""
    stderr_data = ""
    exit_code = nil

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
      end
    end
    ssh.loop
    [stdout_data, stderr_data, exit_code]
  end
end
