# API Authentication

Vulcan provides RESTful API endpoints for programmatic access to projects, components, and rules. Authentication is required for all API endpoints.

## Authentication Methods

### 1. Session-based Authentication (Cookies)

When logged in through the web interface, your session cookie automatically authenticates API requests from the same browser.

```javascript
// Browser-based API call (session cookie included automatically)
fetch('/api/v1/projects', {
  credentials: 'same-origin'
})
  .then(response => response.json())
  .then(data => console.log(data));
```

### 2. API Token Authentication

For programmatic access, use API tokens in the Authorization header:

```bash
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://vulcan.example.com/api/v1/projects
```

### 3. Personal Access Tokens

Generate personal access tokens from your user profile:

1. Navigate to User Settings > API Tokens
2. Click "Generate New Token"
3. Give your token a descriptive name
4. Copy the token immediately (it won't be shown again)

## Request Headers

All API requests should include:

```http
Accept: application/json
Content-Type: application/json
Authorization: Bearer YOUR_API_TOKEN
```

## Authentication Errors

### 401 Unauthorized

Missing or invalid authentication credentials:

```json
{
  "error": "Unauthorized",
  "message": "Invalid or missing authentication token"
}
```

### 403 Forbidden

Valid authentication but insufficient permissions:

```json
{
  "error": "Forbidden",
  "message": "You don't have permission to access this resource"
}
```

## CORS Configuration

For cross-origin requests, configure CORS in your Vulcan deployment:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://trusted-domain.com'
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options]
  end
end
```

## Rate Limiting

API requests are rate-limited to prevent abuse:

- **Authenticated requests**: 1000 per hour
- **Unauthenticated requests**: 60 per hour

Rate limit headers are included in responses:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
```

## OAuth 2.0 Support

Vulcan supports OAuth 2.0 for third-party application integration:

### Authorization Code Flow

1. **Redirect user to authorize**:
```
https://vulcan.example.com/oauth/authorize?
  client_id=YOUR_CLIENT_ID&
  redirect_uri=YOUR_REDIRECT_URI&
  response_type=code&
  scope=read+write
```

2. **Exchange code for token**:
```bash
curl -X POST https://vulcan.example.com/oauth/token \
  -d "grant_type=authorization_code" \
  -d "code=AUTHORIZATION_CODE" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "redirect_uri=YOUR_REDIRECT_URI"
```

3. **Use access token**:
```bash
curl -H "Authorization: Bearer ACCESS_TOKEN" \
     https://vulcan.example.com/api/v1/projects
```

## Best Practices

1. **Token Security**
   - Never commit tokens to version control
   - Use environment variables for token storage
   - Rotate tokens regularly
   - Revoke unused tokens

2. **HTTPS Only**
   - Always use HTTPS in production
   - Never send tokens over unencrypted connections

3. **Scope Limitations**
   - Request minimum necessary permissions
   - Use read-only tokens when write access isn't needed

4. **Error Handling**
   - Implement token refresh logic for expired tokens
   - Handle rate limiting with exponential backoff

## Example Implementation

### Ruby Client

```ruby
require 'net/http'
require 'json'

class VulcanClient
  def initialize(api_token)
    @api_token = api_token
    @base_url = 'https://vulcan.example.com'
  end

  def get_projects
    uri = URI("#{@base_url}/api/v1/projects")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_token}"
    request['Accept'] = 'application/json'
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    JSON.parse(response.body)
  end
end

client = VulcanClient.new(ENV['VULCAN_API_TOKEN'])
projects = client.get_projects
```

### Python Client

```python
import requests
import os

class VulcanClient:
    def __init__(self, api_token):
        self.api_token = api_token
        self.base_url = 'https://vulcan.example.com'
        self.headers = {
            'Authorization': f'Bearer {api_token}',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        }
    
    def get_projects(self):
        response = requests.get(
            f'{self.base_url}/api/v1/projects',
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()

client = VulcanClient(os.environ['VULCAN_API_TOKEN'])
projects = client.get_projects()
```

## Token Management API

### List tokens
```
GET /api/v1/user/tokens
```

### Create token
```
POST /api/v1/user/tokens
{
  "name": "CI/CD Token",
  "scopes": ["read", "write"]
}
```

### Revoke token
```
DELETE /api/v1/user/tokens/:id
```