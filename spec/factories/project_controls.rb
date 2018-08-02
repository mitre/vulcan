FactoryBot.define do
  factory :control_applicable_not_started, class: ProjectControl do
    title "The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values."
    desc "Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010."
    impact 0.7
    refs ['MyString']
    code "control \"V-71849\" do\n  title \"The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values.\"\n  desc  \"\n    Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.\n  \"\n  impact 0.7\n  tag \"severity\": \"high\"\n  tag \"gtitle\": \"SRG-OS-000257-GPOS-00098\"\n  tag \"gid\": \"V-71849\"\n  tag \"rid\": \"SV-86473r2_rule\"\n  tag \"stig_id\": \"RHEL-07-010010\"\n  tag \"cci\": \"CCI-001494\"\n  tag \"nist\": [\"AU-9\", \"Rev_4\"]\n  tag \"cci\": \"CCI-001496\"\n  tag \"nist\": [\"AU-9 (3)\", \"Rev_4\"]\n  tag \"check\": \"Verify the file permissions, ownership, and group membership of\nsystem files and commands match the vendor values.\n\nCheck the file permissions, ownership, and group membership of system files and\ncommands with the following command:\n\n# rpm -Va | grep '^.M'\n\nIf there is any output from the command indicating that the ownership or group of a\nsystem file or command, or a system file, has permissions less restrictive than the\ndefault, this is a finding.\"\n\n  tag \"fix\": \"Run the following command to determine which package owns the file:\n\n# rpm -qf <filename>\n\nReset the permissions of files within a package with the following command:\n\n#rpm --setperms <packagename>\n\nReset the user and group ownership of files within a package with the following\ncommand:\n\n#rpm --setugids <packagename>\"\n\n  # @todo add puppet content to fix any rpms that get out of wack\n  describe command(\"rpm -Va | grep '^.M' | wc -l\") do\n    its('stdout.strip') { should eq '0' }\n  end\n\nend\n"
    control_id 'V-71849'
    checktext 'must provide something'
    fixtext 'do something'
    applicability 'Applicable - Configurable'
    status 'Not Started'
    sl_ref 'profiles/disa_stig-rhel7-baseline/controls/V-71849.rb'
    sl_line 23
  end
  
  factory :control_applicable_awaiting_review, class: ProjectControl do
    title "The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values."
    desc "Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010."
    impact 0.7
    refs ['MyString']
    code "control \"V-71849\" do\n  title \"The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values.\"\n  desc  \"\n    Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.\n  \"\n  impact 0.7\n  tag \"severity\": \"high\"\n  tag \"gtitle\": \"SRG-OS-000257-GPOS-00098\"\n  tag \"gid\": \"V-71849\"\n  tag \"rid\": \"SV-86473r2_rule\"\n  tag \"stig_id\": \"RHEL-07-010010\"\n  tag \"cci\": \"CCI-001494\"\n  tag \"nist\": [\"AU-9\", \"Rev_4\"]\n  tag \"cci\": \"CCI-001496\"\n  tag \"nist\": [\"AU-9 (3)\", \"Rev_4\"]\n  tag \"check\": \"Verify the file permissions, ownership, and group membership of\nsystem files and commands match the vendor values.\n\nCheck the file permissions, ownership, and group membership of system files and\ncommands with the following command:\n\n# rpm -Va | grep '^.M'\n\nIf there is any output from the command indicating that the ownership or group of a\nsystem file or command, or a system file, has permissions less restrictive than the\ndefault, this is a finding.\"\n\n  tag \"fix\": \"Run the following command to determine which package owns the file:\n\n# rpm -qf <filename>\n\nReset the permissions of files within a package with the following command:\n\n#rpm --setperms <packagename>\n\nReset the user and group ownership of files within a package with the following\ncommand:\n\n#rpm --setugids <packagename>\"\n\n  # @todo add puppet content to fix any rpms that get out of wack\n  describe command(\"rpm -Va | grep '^.M' | wc -l\") do\n    its('stdout.strip') { should eq '0' }\n  end\n\nend\n"
    control_id 'V-71849'
    checktext 'must provide something'
    fixtext 'do something'
    applicability 'Applicable - Configurable'
    status 'Awaiting Review'
    sl_ref 'profiles/disa_stig-rhel7-baseline/controls/V-71849.rb'
    sl_line 23
  end
  
  factory :control_applicable_needs_changes, class: ProjectControl do
    title "The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values."
    desc "Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010."
    impact 0.7
    refs ['MyString']
    code "control \"V-71849\" do\n  title \"The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values.\"\n  desc  \"\n    Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.\n  \"\n  impact 0.7\n  tag \"severity\": \"high\"\n  tag \"gtitle\": \"SRG-OS-000257-GPOS-00098\"\n  tag \"gid\": \"V-71849\"\n  tag \"rid\": \"SV-86473r2_rule\"\n  tag \"stig_id\": \"RHEL-07-010010\"\n  tag \"cci\": \"CCI-001494\"\n  tag \"nist\": [\"AU-9\", \"Rev_4\"]\n  tag \"cci\": \"CCI-001496\"\n  tag \"nist\": [\"AU-9 (3)\", \"Rev_4\"]\n  tag \"check\": \"Verify the file permissions, ownership, and group membership of\nsystem files and commands match the vendor values.\n\nCheck the file permissions, ownership, and group membership of system files and\ncommands with the following command:\n\n# rpm -Va | grep '^.M'\n\nIf there is any output from the command indicating that the ownership or group of a\nsystem file or command, or a system file, has permissions less restrictive than the\ndefault, this is a finding.\"\n\n  tag \"fix\": \"Run the following command to determine which package owns the file:\n\n# rpm -qf <filename>\n\nReset the permissions of files within a package with the following command:\n\n#rpm --setperms <packagename>\n\nReset the user and group ownership of files within a package with the following\ncommand:\n\n#rpm --setugids <packagename>\"\n\n  # @todo add puppet content to fix any rpms that get out of wack\n  describe command(\"rpm -Va | grep '^.M' | wc -l\") do\n    its('stdout.strip') { should eq '0' }\n  end\n\nend\n"
    control_id 'V-71849'
    checktext 'must provide something'
    fixtext 'do something'
    applicability 'Applicable - Configurable'
    status 'Needs Changes'
    sl_ref 'profiles/disa_stig-rhel7-baseline/controls/V-71849.rb'
    sl_line 23
  end
  
  factory :control_applicable_approved, class: ProjectControl do
    title "The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values."
    desc "Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010."
    impact 0.7
    refs ['MyString']
    code "control \"V-71849\" do\n  title \"The file permissions, ownership, and group membership of system files and\ncommands must match the vendor values.\"\n  desc  \"\n    Discretionary access control is weakened if a user or group has access\npermissions to system files and directories greater than the default.\n\n    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.\n  \"\n  impact 0.7\n  tag \"severity\": \"high\"\n  tag \"gtitle\": \"SRG-OS-000257-GPOS-00098\"\n  tag \"gid\": \"V-71849\"\n  tag \"rid\": \"SV-86473r2_rule\"\n  tag \"stig_id\": \"RHEL-07-010010\"\n  tag \"cci\": \"CCI-001494\"\n  tag \"nist\": [\"AU-9\", \"Rev_4\"]\n  tag \"cci\": \"CCI-001496\"\n  tag \"nist\": [\"AU-9 (3)\", \"Rev_4\"]\n  tag \"check\": \"Verify the file permissions, ownership, and group membership of\nsystem files and commands match the vendor values.\n\nCheck the file permissions, ownership, and group membership of system files and\ncommands with the following command:\n\n# rpm -Va | grep '^.M'\n\nIf there is any output from the command indicating that the ownership or group of a\nsystem file or command, or a system file, has permissions less restrictive than the\ndefault, this is a finding.\"\n\n  tag \"fix\": \"Run the following command to determine which package owns the file:\n\n# rpm -qf <filename>\n\nReset the permissions of files within a package with the following command:\n\n#rpm --setperms <packagename>\n\nReset the user and group ownership of files within a package with the following\ncommand:\n\n#rpm --setugids <packagename>\"\n\n  # @todo add puppet content to fix any rpms that get out of wack\n  describe command(\"rpm -Va | grep '^.M' | wc -l\") do\n    its('stdout.strip') { should eq '0' }\n  end\n\nend\n"
    control_id 'V-71849'
    checktext 'must provide something'
    fixtext 'do something'
    applicability 'Applicable - Configurable'
    status 'Approved'
    sl_ref 'profiles/disa_stig-rhel7-baseline/controls/V-71849.rb'
    sl_line 23
  end

  factory :control_not_applicable, class: ProjectControl do
    title 'The file permissions, ownership, and group membership of system files and commands must match the vendor values.'
    description 'Discretionary access control is weakened if a user or group has access permissions to system files and directories greater than the default.    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.'
    impact 1.5
    code "control \"V-71849\" do\n  title \"The file permissions, ownership, and group membership of system files and commands must match the vendor values.\"\n  desc  \"\n    Discretionary access control is weakened if a user or group has access permissions to system files and directories greater than the default.    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.\n  \"\n  impact 0.7\n  tag \"severity\": \"high\"\n  tag \"gtitle\": \"SRG-OS-000257-GPOS-00098\"\n  tag \"gid\": \"V-71849\"\n  tag \"rid\": \"SV-86473r2_rule\"\n  tag \"stig_id\": \"RHEL-07-010010\"\n  tag \"cci\": \"CCI-001494\"\n  tag \"nist\": [\"AU-9\", \"Rev_4\"]\n  tag \"cci\": \"CCI-001496\"\n  tag \"nist\": [\"AU-9 (3)\", \"Rev_4\"]\n  tag \"check\": \"Verify the file permissions, ownership, and group membership of\nsystem files and commands match the vendor values.\n\nCheck the file permissions, ownership, and group membership of system files and\ncommands with the following command:\n\n# rpm -Va | grep '^.M'\n\nIf there is any output from the command indicating that the ownership or group of a\nsystem file or command, or a system file, has permissions less restrictive than the\ndefault, this is a finding.\"\n\n  tag \"fix\": \"Run the following command to determine which package owns the file:\n\n# rpm -qf <filename>\n\nReset the permissions of files within a package with the following command:\n\n#rpm --setperms <packagename>\n\nReset the user and group ownership of files within a package with the following\ncommand:\n\n#rpm --setugids <packagename>\"\n\n  # @todo add puppet content to fix any rpms that get out of wack\n  describe command(\"rpm -Va | grep '^.M' | wc -l\") do\n    its('stdout.strip') { should eq '0' }\n  end\n\nend\n"
    control_id 'V-71849'
    checktext 'must provide something'
    fixtext 'do something'
    applicability 'Not Applicable'
    justification 'reason'
    sl_ref 'profiles/disa_stig-rhel7-baseline/controls/V-71849.rb'
    sl_line 23
  end
  
  factory :control_inherently_meets, class: ProjectControl do
    title 'The file permissions, ownership, and group membership of system files and commands must match the vendor values.'
    description 'Discretionary access control is weakened if a user or group has access permissions to system files and directories greater than the default.    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.'
    impact 1.5
    code "control \"V-71849\" do\n  title \"The file permissions, ownership, and group membership of system files and commands must match the vendor values.\"\n  desc  \"\n    Discretionary access control is weakened if a user or group has access permissions to system files and directories greater than the default.    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.\n  \"\n  impact 0.7\n  tag \"severity\": \"high\"\n  tag \"gtitle\": \"SRG-OS-000257-GPOS-00098\"\n  tag \"gid\": \"V-71849\"\n  tag \"rid\": \"SV-86473r2_rule\"\n  tag \"stig_id\": \"RHEL-07-010010\"\n  tag \"cci\": \"CCI-001494\"\n  tag \"nist\": [\"AU-9\", \"Rev_4\"]\n  tag \"cci\": \"CCI-001496\"\n  tag \"nist\": [\"AU-9 (3)\", \"Rev_4\"]\n  tag \"check\": \"Verify the file permissions, ownership, and group membership of\nsystem files and commands match the vendor values.\n\nCheck the file permissions, ownership, and group membership of system files and\ncommands with the following command:\n\n# rpm -Va | grep '^.M'\n\nIf there is any output from the command indicating that the ownership or group of a\nsystem file or command, or a system file, has permissions less restrictive than the\ndefault, this is a finding.\"\n\n  tag \"fix\": \"Run the following command to determine which package owns the file:\n\n# rpm -qf <filename>\n\nReset the permissions of files within a package with the following command:\n\n#rpm --setperms <packagename>\n\nReset the user and group ownership of files within a package with the following\ncommand:\n\n#rpm --setugids <packagename>\"\n\n  # @todo add puppet content to fix any rpms that get out of wack\n  describe command(\"rpm -Va | grep '^.M' | wc -l\") do\n    its('stdout.strip') { should eq '0' }\n  end\n\nend\n"
    control_id 'V-71849'
    checktext 'must provide something'
    fixtext 'do something'
    applicability 'Applicable - Inherently Meets'
    justification 'reason'
    sl_ref 'profiles/disa_stig-rhel7-baseline/controls/V-71849.rb'
    sl_line 23
  end
  
  factory :control_does_not_meet, class: ProjectControl do
    title 'The file permissions, ownership, and group membership of system files and commands must match the vendor values.'
    description 'Discretionary access control is weakened if a user or group has access permissions to system files and directories greater than the default.    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.'
    impact 1.5
    code "control \"V-71849\" do\n  title \"The file permissions, ownership, and group membership of system files and commands must match the vendor values.\"\n  desc  \"\n    Discretionary access control is weakened if a user or group has access permissions to system files and directories greater than the default.    Satisfies: SRG-OS-000257-GPOS-00098, SRG-OS-000278-GPOS-0010.\n  \"\n  impact 0.7\n  tag \"severity\": \"high\"\n  tag \"gtitle\": \"SRG-OS-000257-GPOS-00098\"\n  tag \"gid\": \"V-71849\"\n  tag \"rid\": \"SV-86473r2_rule\"\n  tag \"stig_id\": \"RHEL-07-010010\"\n  tag \"cci\": \"CCI-001494\"\n  tag \"nist\": [\"AU-9\", \"Rev_4\"]\n  tag \"cci\": \"CCI-001496\"\n  tag \"nist\": [\"AU-9 (3)\", \"Rev_4\"]\n  tag \"check\": \"Verify the file permissions, ownership, and group membership of\nsystem files and commands match the vendor values.\n\nCheck the file permissions, ownership, and group membership of system files and\ncommands with the following command:\n\n# rpm -Va | grep '^.M'\n\nIf there is any output from the command indicating that the ownership or group of a\nsystem file or command, or a system file, has permissions less restrictive than the\ndefault, this is a finding.\"\n\n  tag \"fix\": \"Run the following command to determine which package owns the file:\n\n# rpm -qf <filename>\n\nReset the permissions of files within a package with the following command:\n\n#rpm --setperms <packagename>\n\nReset the user and group ownership of files within a package with the following\ncommand:\n\n#rpm --setugids <packagename>\"\n\n  # @todo add puppet content to fix any rpms that get out of wack\n  describe command(\"rpm -Va | grep '^.M' | wc -l\") do\n    its('stdout.strip') { should eq '0' }\n  end\n\nend\n"
    control_id 'V-71849'
    checktext 'must provide something'
    fixtext 'do something'
    justification 'reason'
    applicability 'Applicable - Does Not Meet'
    sl_ref 'profiles/disa_stig-rhel7-baseline/controls/V-71849.rb'
    sl_line 23
  end
end