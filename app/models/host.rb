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

  def download(remote_path, local_path, opt = {recursive: true})
    start_sftp do |sftp|
      rpath = expand_remote_home_path(remote_path)
      sftp.download!(rpath, local_path, opt)
    end
  end

  # def upload(local_path, remote_path, sftp = nil)
  #   if sftp
  #     rpath = expand_remote_home_path(remote_path)
  #     sftp.upload!(local_path, rpath, recursive: true)
  #   else
  #     start_sftp {|sftp| upload(local_path, remote_path, sftp) }
  #   end
  # end

  def rm_r(remote_path)
    rpath = expand_remote_home_path(remote_path)
    start_ssh do |ssh|
      ssh.exec!("rm -r #{rpath}")
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
    Run.where(submitted_to: self).in(status: [:submitted, :running])
  end

  def submit(runs)
    start_ssh do |ssh|
      # copy job_script and input_json files
      job_script_paths = prepare_job_script_for(runs)

      # enqueue jobs
      job_script_paths.each do |run_id, path|
        run = Run.find(run_id)
        ssh.exec!("chmod +x #{path}")
        ssh.exec!("#{submission_command} #{path} &")
        run.status = :submitted
        run.submitted_to = self
        run.save!
      end
      job_script_paths
    end
  end

  def check_submitted_job_status
    return if submitted_runs.count == 0
    start_ssh do |ssh|
      # check if job is finished
      submitted_runs.each do |run|
        case remote_status(run)
        when :submitted
          # DO NOTHING
        when :running
          if run.status == :submitted
            run.status = :running
            run.save
          end
        when :includable
          rpath = result_file_path(run)
          base = File.basename(rpath)
          download(rpath, run.dir.join('..', base), {recursive: false})
          JobScriptUtil.expand_result_file_and_update_run(run)
          run.reload
          if run.status == :finished
            rm_r( result_file_path(run) )
            rm_r( job_script_path(run) )
          end
        end
      end
    end
  end

  private
  def start_ssh
    if @ssh
      yield @ssh
    else
      Net::SSH.start(hostname, user, password: "", timeout: 1, keys: ssh_key, port: port) do |ssh|
        @ssh = ssh
        begin
          yield ssh
        ensure
          @ssh = nil
        end
      end
    end
  end

  def start_sftp
    start_ssh do |ssh|
      yield ssh.sftp
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

  # Net::SSH and Net::SFTP can't interpret '~' as a home directory
  # a relative path is recognized as a relative path from home directory
  # so replace '~' with '.' in this method
  def expand_remote_home_path(path)
    Pathname.new( path.to_s.sub(/^~/, '.') )
  end

  def prepare_job_script_for(runs)
    script_paths = {}
    start_sftp do |sftp|
      runs.each do |run|
        # prepare job script
        spath = job_script_path(run)
        sftp.file.open(spath, 'w') { |f|
          f.print JobScriptUtil.script_for(run, self)
        }
        script_paths[run.id] = spath

        # prepare _input.json
        input = run.command_and_input[1]
        if input
          sftp.file.open(input_json_path(run), 'w') { |f|
            f.print input.to_json
          }
        end
      end
    end
    script_paths
  end

  def job_script_path(run)
    base = expand_remote_home_path(work_base_dir)
    base.join("#{run.id}.sh")
  end

  def input_json_path(run)
    base = expand_remote_home_path(work_base_dir)
    base.join("#{run.id}_input.json")
  end

  def work_dir_path(run)
    base = expand_remote_home_path(work_base_dir)
    base.join("#{run.id}")
  end

  def result_file_path(run)
    base = expand_remote_home_path(work_base_dir)
    base.join("#{run.id}.tar.bz2")
  end

  def remote_path_exist?(path)
    start_ssh do |ssh|
      cmd = "if [ -e '#{path}' ]; then echo -n 'true'; fi"
      return true if ssh_exec!(ssh, cmd)[0] == 'true'
    end
    return false
  end

  def remote_status(run)
    status = :submitted
    if remote_path_exist?( work_dir_path(run) )
      status = :running
    elsif remote_path_exist?( result_file_path(run) )
      status = :includable
    end
    status
  end
end
