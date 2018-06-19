class HostConfigsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def add_host_config
    host_config = HostConfig.create(host_config_params)
    render json: {id: host_config.id, option: format_host_as_option(host_config)}
  end
  
  def delete_host_config
    host_config = HostConfig.find(params['host_configs']['id'])
    host_config.destroy
  end
  
  private 
  def format_host_as_option(config)
    return "SSH - " + config.user + " - " + config.host + ' - ' + config.port if config.transport_method == 'SSH'
    return "Docker - " + config.user + " - " + config.host + ' - ' + config.port if config.transport_method == 'Docker'
    return "AWS - " + (config.aws_region || 'null') + ' - ' + (config.aws_profile || 'null') if config.transport_method == 'AWS'
  end
  
  # Never trust parameters from the scary internet, only allow the white list through.
  def host_config_params
    params.require('host_configs').permit(:user_id, :host, :user, :password, :port, :transport_method, :aws_region, :aws_access_key, :aws_secret_key)
  end
end
