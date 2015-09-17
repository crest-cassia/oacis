module Executable

  def self.included(base)
    base.send(:field, :command, type: String)
    base.send(:field, :support_input_json, type: Boolean, default: false)
    base.send(:field, :support_mpi, type: Boolean, default: false)
    base.send(:field, :support_omp, type: Boolean, default: false)
    base.send(:field, :pre_process_script, type: String)
    base.send(:field, :print_version_command, type: String)
    base.send(:field, :default_host_parameters, type: Hash, default: {}) # {Host.id => {host_param1 => foo, ...}}
    base.send(:field, :default_mpi_procs, type: Hash, default: {}) # {Host.id => 4, ...}
    base.send(:field, :default_omp_threads, type: Hash, default: {}) # {Host.id => 8, ...}

    field_name = :"executable_#{base.to_s.pluralize.downcase}"   # either simulator or analyzer
    base.send(:has_and_belongs_to_many, :executable_on,
              class_name: "Host",
              inverse_of: field_name)

    base.send(:validates, :command, presence: true)
  end

  public
  def get_default_host_parameter(host)
    if host.present?
      host_id = host.id.to_s
      unless self.default_host_parameters[host_id].present?
        host_parameter = {}
        if host.present?
          key_value = host.host_parameter_definitions.map {|pd| [pd.key, pd.default]}
          host_parameter = Hash[*key_value.flatten]
        end
        self.default_host_parameters[host_id] = host_parameter
        self.timeless.update_attribute(:default_host_parameters, self.default_host_parameters)
      end
      return self.default_host_parameters[host_id]
    else
      return {} # for manual_submission
    end
  end
end
