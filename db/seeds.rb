# frozen_string_literal: true

# rubocop:disable Rails/Output

# Populate the database for demonstration use.
unless Rails.env.development? || ENV.fetch('DISABLE_DATABASE_ENVIRONMENT_CHECK', false)
  raise 'This task is only for use in a development environment'
end

puts "Populating database for demo use:\n\n"
puts 'Creating Users...'
User.create(name: FFaker::Name.name, email: 'admin@example.com', password: '1234567ab!', admin: true)
users = []
10.times do
  name = FFaker::Name.name
  users << User.new(name: name, email: "#{name.split.join('.')}@example.com", password: '1234567ab!')
end
User.import(users)
puts 'Created Users'
puts 'Creating Projects with rules...'
project = Project.create(name: 'Test Project')
Rule.create(
  project: project,
  rule_id: 'SV-53023r3_rule',
  status: 'Applicable - Configurable',
  status_justification: '',
  artifact_description: '',
  vendor_comments: '',
  rule_severity: 'medium',
  rule_weight: '10.0',
  version: 'SRG-APP-000001-WSR-000002',
  title: 'The web server must perform server-side session management.',
  ident: 'CCI-000054',
  ident_system: 'http://iase.disa.mil/cci',
  fixtext: 'Configure the web server to perform server-side session management.',
  fixtext_fixref: 'F-45949r2_fix',
  fix_id: 'F-45949r2_fix',
  disa_rule_descriptions: [
    DisaRuleDescription.new(
      vuln_discussion: 'Session management is the practice of protecting the bulk of the user authorization and'\
                       ' identity information. Storing of this data can occur on the client system or on the'\
                       ' server. When the session information is stored on the client, the session ID, along with the'\
                       ' user authorization and identity information, is sent along with each client request and is'\
                       ' stored in either a cookie, embedded in the uniform resource locator (URL), or placed in a'\
                       ' hidden field on the displayed form. Each of these offers advantages and disadvantages.'\
                       ' The biggest disadvantage to all three is the hijacking of a session along with all of the'\
                       ' user\'s credentials. When the user authorization and identity information is stored on the'\
                       ' server in a protected and encrypted database, the communication between the client and web'\
                       ' server will only send the session identifier, and the server can then retrieve user'\
                       ' credentials for the session when needed. If, during transmission, the session were to be'\
                       ' hijacked, the user\'s credentials would not be compromised.',
      false_positives: '',
      false_negatives: '',
      documentable: false,
      mitigations: '',
      severity_override_guidance: '',
      potential_impacts: '',
      third_party_tools: '',
      mitigation_control: '',
      responsibility: '',
      ia_controls: ''
    )
  ],
  checks: [
    Check.new(
      system: 'C-47329r3_chk',
      content_ref_name: 'M',
      content_ref_href: 'DPMS_XCCDF_Benchmark_Web_Server_SRG.xml',
      content: 'Review the web server documentation and configuration to determine if server-side session management'\
               ' is configured. If it is not configured, this is a finding.'
    )
  ]
)
Rule.create(
  project: project,
  rule_id: 'SV-53035r3_rule',
  status: 'Applicable - Configurable',
  status_justification: '',
  artifact_description: '',
  vendor_comments: '',
  rule_severity: 'medium',
  rule_weight: '10.0',
  version: 'SRG-APP-000016-WSR-000005',
  title: 'The web server must generate information to be used by external applications'\
         ' or entities to monitor and control remote access.',
  ident: 'CCI-000067',
  ident_system: 'http://iase.disa.mil/cci',
  fixtext: 'Configure the web server to provide remote connection information to external'\
           ' monitoring and access control applications.',
  fixtext_fixref: 'F-45961r2_fix',
  fix_id: 'F-45961r2_fix',
  disa_rule_descriptions: [
    DisaRuleDescription.new(
      vuln_discussion: 'Remote access to the web server is any access that communicates through an external,'\
                       ' non-organization-controlled network. Remote access can be used to access hosted'\
                       ' applications or to perform management functions. By providing remote access information'\
                       ' to an external monitoring system, the organization can monitor for cyber attacks and'\
                       ' monitor compliance with remote access policies. The organization can also look at data'\
                       ' organization wide and determine an attack or anomaly is occurring on the organization'\
                       ' which might not be noticed if the data were kept local to the web server. Examples'\
                       ' of external applications used to monitor or control access would be audit log monitoring'\
                       ' systems, dynamic firewalls, or infrastructure monitoring systems.',
      false_positives: '',
      false_negatives: '',
      documentable: false,
      mitigations: '',
      severity_override_guidance: '',
      potential_impacts: '',
      third_party_tools: '',
      mitigation_control: '',
      responsibility: '',
      ia_controls: ''
    )
  ],
  checks: [
    Check.new(
      system: 'C-47342r2_chk',
      content_ref_name: 'M',
      content_ref_href: 'DPMS_XCCDF_Benchmark_Web_Server_SRG.xml',
      content: 'Review the web server documentation and configuration to determine if the web server is configured to'\
               ' generate information for external applications monitoring remote access. If a mechanism is not in'\
               ' place providing information to an external application used to monitor and control access,'\
               ' this is a finding.'
    )
  ]
)
puts 'Created Rules'

puts 'Adding Users to Projects...'
project_members = []
User.all.each do |user|
  project_members << ProjectMember.new(user: user, project: project)
end
ProjectMember.import(project_members)
puts 'Project Members added'

# Counter cache update
Project.all.each { |p| Project.reset_counters(p.id, :project_members) }
# rubocop:enable Rails/Output
