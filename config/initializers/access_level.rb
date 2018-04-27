if ENV.has_key?('OACIS_ACCESS_LEVEL')
  OACIS_ACCESS_LEVEL = Integer(ENV['OACIS_ACCESS_LEVEL'])
else
  OACIS_ACCESS_LEVEL = AcmProto::Application.config.user_config["access_level"] || 2
end
