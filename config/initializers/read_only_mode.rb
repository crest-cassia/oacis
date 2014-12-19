if AcmProto::Application.config.user_config["read_only"]
  OACIS_READ_ONLY = true
else
  OACIS_READ_ONLY = false
end
