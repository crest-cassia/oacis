json.array!(@host_groups) do |host_group|
  json.extract! host_group, :id
  json.url host_group_url(host_group, format: :json)
end
