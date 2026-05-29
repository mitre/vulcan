# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding rule descriptions...'

container_platform = Project.find_by(name: 'Container Platform')
container_component = container_platform&.components&.find_by(name: 'Container Platform')

if container_component.nil?
  puts '  No Container Platform component — skipping rule descriptions'
  return
end

rules = container_component.rules.order(:rule_id).limit(3).to_a

description_data = [
  {
    rule: rules[0],
    description: '<VulnDiscussion>The container platform must use TLS 1.2 or greater for secure container image transport from trusted sources. Without verification of the security channel, container images may be intercepted and modified in transit, introducing malicious code into the environment.</VulnDiscussion><FalsePositives></FalsePositives><FalseNegatives></FalseNegatives><Documentable>false</Documentable><Mitigations></Mitigations><SeverityOverrideGuidance></SeverityOverrideGuidance><PotentialImpacts></PotentialImpacts><ThirdPartyTools></ThirdPartyTools><MitigationControl></MitigationControl><Responsibility></Responsibility><IAControls></IAControls>'
  },
  {
    rule: rules[1],
    description: '<VulnDiscussion>The container platform must use TLS 1.2 or greater for all node-to-node and component communication within the cluster. Unencrypted internal communication allows adversaries with network access to intercept authentication tokens, configuration data, and workload secrets in transit.</VulnDiscussion><FalsePositives></FalsePositives><FalseNegatives></FalseNegatives><Documentable>false</Documentable><Mitigations></Mitigations><SeverityOverrideGuidance></SeverityOverrideGuidance><PotentialImpacts></PotentialImpacts><ThirdPartyTools></ThirdPartyTools><MitigationControl></MitigationControl><Responsibility></Responsibility><IAControls></IAControls>'
  },
  {
    rule: rules[2],
    description: '<VulnDiscussion>The container platform must use a centralized user management solution to manage accounts. Centralized management provides a single point for account provisioning, deprovisioning, and access review, reducing the risk of orphaned accounts and unauthorized access.</VulnDiscussion><FalsePositives></FalsePositives><FalseNegatives></FalseNegatives><Documentable>false</Documentable><Mitigations></Mitigations><SeverityOverrideGuidance></SeverityOverrideGuidance><PotentialImpacts></PotentialImpacts><ThirdPartyTools></ThirdPartyTools><MitigationControl></MitigationControl><Responsibility></Responsibility><IAControls></IAControls>'
  }
]

description_data.each do |entry|
  next unless entry[:rule]

  RuleDescription.find_or_create_by!(
    base_rule: entry[:rule]
  ) do |rd|
    rd.description = entry[:description]
  end
end

puts "  #{RuleDescription.count} rule descriptions total"
# rubocop:enable Rails/Output
