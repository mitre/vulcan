# # Vulcan configuration

default['vulcan']['config_directory'] = '/etc/vulcan'
default['vulcan']['install_directory'] = '/opt/vulcan'
default['vulcan']['app_directory'] = "#{node['vulcan']['install_directory']}/embedded/service/vulcan"
default['vulcan']['log_directory'] = '/var/log/vulcan'
default['vulcan']['var_directory'] = '/var/opt/vulcan'
default['vulcan']['data_directory'] = '/var/opt/vulcan/data'
default['vulcan']['user'] = 'vulcan'
default['vulcan']['group'] = 'vulcan'
