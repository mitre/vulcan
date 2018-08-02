FactoryBot.define do
  factory :host_config_local, class: HostConfig do
    host 'localhost'
    transport_method 'local'
  end
  
  factory :host_config_aws, class: HostConfig do
    host 'awshost'
    transport_method 'aws'
    user 'awsuser'
    password 'password'
    port '5432'
    aws_region 'us-east-1'
    aws_access_key 'access_key'
    aws_secret_key 'secret_key'
  end

  factory :invalid_host_config, class: HostConfig do
    cci nil
  end
end