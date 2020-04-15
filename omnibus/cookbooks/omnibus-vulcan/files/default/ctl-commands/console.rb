# due to how things are being exec'ed, the CWD will be all wrong,
# so we want to use the full path when loaded from omnibus-ctl,
# but we need the local relative path for it to work with rspec
begin
  require 'helpers/ctl_command_helper'
rescue LoadError
  require '/opt/vulcan/embedded/service/omnibus-ctl/helpers/ctl_command_helper'
end

add_command_under_category 'console', 'general', 'Enter the rails console for vulcan', 1 do
  cmd_helper = CtlCommandHelper.new('console')
  cmd_helper.must_run_as 'vulcan'

  cmd = 'cd /opt/vulcan/embedded/service/vulcan && env PATH=/opt/vulcan/embedded/bin:$PATH bin/rails console production'
  exec cmd
  true
end
