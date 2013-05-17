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

  public
  def download(remote_path, local_path)
    raise "Not an absolute path: #{remote_path}" unless Pathname.new(remote_path).absolute?
    Net::SFTP.start(hostname, user) do |sftp|
      sftp.download!(remote_path, local_path, recursive: true)
    end
  end

  def rm_r(remote_path)
    raise "Not an abosolute path:#{remote_path}" unless Pathname.new(remote_path).absolute?
    Net::SSH.start(hostname, user) do |ssh|
      ssh.exec!("rm -r #{remote_path}")
    end
  end
end
