class Host
  include Mongoid::Document
  field :name, type: String
  field :hostname, type: String
  field :user, type: String
  field :port, type: Integer
  field :ssh_key, type: String
  field :show_status_command, type: String
  field :submission_command, type: String
  field :work_base_dir, type: String
  field :simulator_base_dir, type: String
end
