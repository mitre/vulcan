user node['vulcan']['user']

group node['vulcan']['group'] do
  members [node['vulcan']['user']]
end

directory node['vulcan']['var_directory'] do
  owner node['vulcan']['user']
  group node['vulcan']['group']
  mode '0700'
  recursive true
end

directory node['vulcan']['log_directory'] do
  owner node['vulcan']['user']
  group node['vulcan']['group']
  mode '0700'
  recursive true
end

directory "#{node['vulcan']['var_directory']}/etc" do
  owner node['vulcan']['user']
  group node['vulcan']['group']
  mode '0700'
end
