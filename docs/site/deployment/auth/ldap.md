# LDAP Authentication

This guide covers configuring LDAP/Active Directory authentication for Vulcan.

## Prerequisites

- LDAP or Active Directory server
- LDAP bind credentials (service account)
- Network connectivity between Vulcan and LDAP server
- SSL certificates for LDAPS (recommended)

## Basic Configuration

### Environment Variables

```bash
# Enable LDAP authentication
VULCAN_ENABLE_LDAP=true

# LDAP server settings
VULCAN_LDAP_HOST=ldap.example.com
VULCAN_LDAP_PORT=389
VULCAN_LDAP_TITLE="Corporate LDAP"

# Bind credentials
VULCAN_LDAP_BIND_DN="CN=service-account,CN=Users,DC=example,DC=com"
VULCAN_LDAP_ADMIN_PASS="service_account_password"

# Search base
VULCAN_LDAP_BASE="DC=example,DC=com"

# Username attribute
VULCAN_LDAP_ATTRIBUTE=uid  # or sAMAccountName for AD

# Encryption
VULCAN_LDAP_ENCRYPTION=plain  # or simple_tls, start_tls
```

### Configuration File

Edit `config/vulcan.yml`:

```yaml
production:
  ldap:
    enabled: true
    servers:
      main:
        host: ldap.example.com
        port: 389
        title: "Corporate LDAP"
        uid: uid  # or sAMAccountName for Active Directory
        encryption: plain
        bind_dn: "CN=service-account,CN=Users,DC=example,DC=com"
        password: "service_account_password"
        base: "DC=example,DC=com"
```

## Active Directory Configuration

### Standard Active Directory

```yaml
ldap:
  enabled: true
  servers:
    main:
      host: dc01.corp.example.com
      port: 389
      title: "Active Directory"
      uid: sAMAccountName
      encryption: start_tls
      bind_dn: "CN=Vulcan Service,CN=Service Accounts,DC=corp,DC=example,DC=com"
      password: "secure_password"
      base: "DC=corp,DC=example,DC=com"
      # AD-specific options
      filter: "(&(objectClass=user)(memberOf=CN=VulcanUsers,CN=Groups,DC=corp,DC=example,DC=com))"
      attributes:
        username: ['sAMAccountName', 'uid']
        email: ['mail', 'userPrincipalName']
        name: 'displayName'
        first_name: 'givenName'
        last_name: 'sn'
```

### Multiple Domain Controllers

```yaml
ldap:
  enabled: true
  servers:
    primary:
      host: dc01.corp.example.com
      port: 636
      title: "Primary DC"
      uid: sAMAccountName
      encryption: simple_tls
      bind_dn: "CN=Service,CN=Users,DC=corp,DC=example,DC=com"
      password: "secure_password"
      base: "DC=corp,DC=example,DC=com"
    
    secondary:
      host: dc02.corp.example.com
      port: 636
      title: "Secondary DC"
      uid: sAMAccountName
      encryption: simple_tls
      bind_dn: "CN=Service,CN=Users,DC=corp,DC=example,DC=com"
      password: "secure_password"
      base: "DC=corp,DC=example,DC=com"
```

## Secure LDAP (LDAPS)

### Simple TLS (Port 636)

```yaml
ldap:
  servers:
    main:
      host: ldaps.example.com
      port: 636
      encryption: simple_tls
      tls_options:
        ca_file: /path/to/ca_certificate.pem
        ssl_version: TLSv1_2
        verify_mode: OpenSSL::SSL::VERIFY_PEER
```

### StartTLS (Port 389)

```yaml
ldap:
  servers:
    main:
      host: ldap.example.com
      port: 389
      encryption: start_tls
      tls_options:
        ca_file: /path/to/ca_certificate.pem
        ssl_version: TLSv1_2
```

## User Filtering

### Group-based Access

```yaml
ldap:
  servers:
    main:
      # ... other settings ...
      # Only allow users in specific groups
      filter: "(&(objectClass=user)(memberOf=CN=VulcanUsers,CN=Groups,DC=example,DC=com))"
      
      # Or multiple groups
      filter: "(|(&(objectClass=user)(memberOf=CN=Developers,CN=Groups,DC=example,DC=com))(&(objectClass=user)(memberOf=CN=Security,CN=Groups,DC=example,DC=com)))"
```

### Attribute-based Filtering

```yaml
ldap:
  servers:
    main:
      # Only active employees
      filter: "(&(objectClass=user)(employeeStatus=active)(department=Engineering))"
```

## Attribute Mapping

### Custom Attribute Mapping

```yaml
ldap:
  servers:
    main:
      # ... other settings ...
      attributes:
        username: 'sAMAccountName'
        email: 'mail'
        name: 'displayName'
        first_name: 'givenName'
        last_name: 'sn'
        department: 'department'
        phone: 'telephoneNumber'
        title: 'title'
        manager: 'manager'
```

### Multiple Attribute Sources

```yaml
ldap:
  servers:
    main:
      attributes:
        # Try multiple attributes in order
        username: ['sAMAccountName', 'uid', 'cn']
        email: ['mail', 'userPrincipalName', 'emailAddress']
```

## Authentication Flow

### User Login Process

1. User enters username and password
2. Vulcan constructs DN from username and base
3. Attempts bind with user credentials
4. If successful, retrieves user attributes
5. Creates or updates local user account
6. Establishes session

### Account Provisioning

```yaml
ldap:
  servers:
    main:
      # ... other settings ...
      # Auto-provision user accounts
      create_user: true
      update_user: true
      
      # Default role for new users
      default_role: 'viewer'
      
      # Admin users (by username)
      admin_users:
        - 'admin_user1'
        - 'admin_user2'
```

## Testing LDAP Connection

### Command Line Test

```bash
# Test LDAP connectivity
ldapsearch -x -H ldap://ldap.example.com:389 \
  -D "CN=service-account,CN=Users,DC=example,DC=com" \
  -W -b "DC=example,DC=com" \
  "(sAMAccountName=testuser)"

# Test LDAPS with TLS
ldapsearch -x -H ldaps://ldap.example.com:636 \
  -D "CN=service-account,CN=Users,DC=example,DC=com" \
  -W -b "DC=example,DC=com" \
  "(sAMAccountName=testuser)"
```

### Rails Console Test

```ruby
# Test LDAP configuration
Rails.console

# Create LDAP connection
require 'net/ldap'
ldap = Net::LDAP.new(
  host: 'ldap.example.com',
  port: 389,
  auth: {
    method: :simple,
    username: "CN=service-account,CN=Users,DC=example,DC=com",
    password: "password"
  }
)

# Test bind
if ldap.bind
  puts "LDAP bind successful"
else
  puts "LDAP bind failed: #{ldap.get_operation_result}"
end

# Search for user
ldap.search(
  base: "DC=example,DC=com",
  filter: "(sAMAccountName=testuser)",
  attributes: ['mail', 'displayName']
) do |entry|
  puts "DN: #{entry.dn}"
  entry.each do |attribute, values|
    puts "   #{attribute}: #{values.join(', ')}"
  end
end
```

## Troubleshooting

### Common Issues

#### Connection Refused

**Problem**: Cannot connect to LDAP server

**Solution**:
```bash
# Check network connectivity
telnet ldap.example.com 389

# Check firewall rules
sudo iptables -L -n | grep 389

# Verify LDAP service is running
nmap -p 389,636 ldap.example.com
```

#### Invalid Credentials

**Problem**: Bind fails with invalid credentials

**Solution**:
1. Verify bind DN format is correct
2. Check password for special characters that need escaping
3. Ensure service account is not locked
4. Test with ldapsearch command

#### User Not Found

**Problem**: Users can't authenticate despite correct credentials

**Solution**:
1. Verify search base is correct
2. Check uid/username attribute matches
3. Review filter if configured
4. Test user search with ldapsearch

#### SSL/TLS Errors

**Problem**: Certificate verification failures

**Solution**:
```yaml
# Temporarily disable verification (not for production!)
tls_options:
  verify_mode: OpenSSL::SSL::VERIFY_NONE

# Or provide CA certificate
tls_options:
  ca_file: /etc/ssl/certs/ldap-ca.pem
  verify_mode: OpenSSL::SSL::VERIFY_PEER
```

### Debug Logging

Enable LDAP debug logging:

```ruby
# config/initializers/ldap_debug.rb
if Rails.env.development?
  Devise::LDAP::Connection.class_eval do
    def initialize(params = {})
      super
      @ldap.verbose = true  # Enable verbose logging
    end
  end
end
```

## Performance Optimization

### Connection Pooling

```yaml
ldap:
  servers:
    main:
      # ... other settings ...
      connection_pool:
        size: 5
        timeout: 5
        checkout_timeout: 2
```

### Caching

```ruby
# Cache LDAP lookups
Rails.cache.fetch("ldap_user_#{username}", expires_in: 1.hour) do
  ldap_lookup(username)
end
```

## Security Best Practices

1. **Use LDAPS or StartTLS**: Always encrypt LDAP traffic
2. **Service Account**: Use dedicated service account with minimal permissions
3. **Strong Bind Password**: Use complex password for bind account
4. **Validate Certificates**: Verify SSL certificates in production
5. **Filter Users**: Restrict access to specific groups or OUs
6. **Audit Logging**: Log all authentication attempts
7. **Rate Limiting**: Implement rate limiting for failed attempts

## High Availability

### Failover Configuration

```yaml
ldap:
  servers:
    main:
      hosts:
        - ldap1.example.com
        - ldap2.example.com
        - ldap3.example.com
      port: 389
      # Failover settings
      timeout: 5
      retry_count: 3
      retry_delay: 2
```

### Load Balancing

Use a load balancer or LDAP proxy:
```yaml
ldap:
  servers:
    main:
      host: ldap-lb.example.com  # Load balancer address
      port: 389
```

## Migration from Local Auth

### Linking Existing Accounts

```ruby
# Script to link LDAP to existing users
User.find_each do |user|
  # Match by email
  ldap_entry = ldap_search(email: user.email)
  
  if ldap_entry
    user.update!(
      ldap_uid: ldap_entry.uid,
      provider: 'ldap'
    )
  end
end
```

## Additional Resources

- [Devise LDAP Authenticatable](https://github.com/cschiewek/devise_ldap_authenticatable)
- [Net::LDAP Documentation](https://github.com/ruby-ldap/ruby-net-ldap)
- [Active Directory LDAP Syntax](https://docs.microsoft.com/en-us/windows/win32/adsi/ldap-filter-syntax)