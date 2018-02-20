require 'json'

File.open("config/tooltip_descs.json") do |file|
  TOOLTIP_DESCS = JSON.load(file)
end
if TOOLTIP_DESCS.nil? == true
  TOOLTIP_DESCS = {}
end
