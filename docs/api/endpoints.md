# API Endpoints

## Overview

Vulcan provides JSON API endpoints for programmatic access to projects, components, STIGs, and SRGs. All endpoints require authentication.

## Authentication

See [Authentication](authentication.md) for details on API authentication methods.

## Base URL

```
https://your-vulcan-instance.com
```

## Endpoints

### Projects

#### List Projects
```http
GET /projects.json
```

Returns a list of projects accessible to the authenticated user.

#### Get Project
```http
GET /projects/:id.json
```

Returns details for a specific project.

#### Create Project
```http
POST /projects.json
```

Creates a new project.

#### Update Project
```http
PUT /projects/:id.json
```

Updates an existing project.

#### Delete Project
```http
DELETE /projects/:id.json
```

Deletes a project (admin only).

### Components

#### List Components
```http
GET /components.json
GET /projects/:project_id/components.json
```

Returns components, optionally filtered by project.

#### Get Component
```http
GET /components/:id.json
```

Returns details for a specific component.

#### Create Component
```http
POST /components.json
```

Creates a new component.

#### Update Component
```http
PUT /components/:id.json
```

Updates an existing component.

#### Export Component
```http
GET /components/:id/export.json
```

Exports component as InSpec profile or XCCDF.

### Rules

#### List Rules
```http
GET /components/:component_id/rules.json
```

Returns rules for a component.

#### Get Rule
```http
GET /rules/:id.json
```

Returns details for a specific rule.

#### Update Rule
```http
PUT /rules/:id.json
```

Updates a rule's content.

### STIGs

#### List STIGs
```http
GET /stigs.json
```

Returns available STIGs.

#### Get STIG
```http
GET /stigs/:id.json
```

Returns details for a specific STIG.

#### Upload STIG
```http
POST /stigs.json
```

Uploads a new STIG file (admin only).

### Security Requirements Guides (SRGs)

#### List SRGs
```http
GET /security_requirements_guides.json
```

Returns available SRGs.

#### Get SRG
```http
GET /security_requirements_guides/:id.json
```

Returns details for a specific SRG.

#### Upload SRG
```http
POST /security_requirements_guides.json
```

Uploads a new SRG file (admin only).

## Response Format

All JSON responses follow this structure:

### Success Response
```json
{
  "data": {
    // Response data
  },
  "status": "success"
}
```

### Error Response
```json
{
  "error": "Error message",
  "status": "error"
}
```

## Pagination

List endpoints support pagination:

```http
GET /projects.json?page=2&per_page=25
```

## Filtering

Some endpoints support filtering:

```http
GET /components.json?project_id=123
GET /rules.json?status=open
```

## Rate Limiting

API requests are limited to:
- 100 requests per minute for authenticated users
- 10 requests per minute for unauthenticated requests

## Examples

### cURL Example
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Accept: application/json" \
     https://vulcan.example.com/projects.json
```

### Ruby Example
```ruby
require 'net/http'
require 'json'

uri = URI('https://vulcan.example.com/projects.json')
req = Net::HTTP::Get.new(uri)
req['Authorization'] = 'Bearer YOUR_TOKEN'
req['Accept'] = 'application/json'

res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
  http.request(req)
end

projects = JSON.parse(res.body)
```

## Status Codes

- `200 OK` - Request successful
- `201 Created` - Resource created
- `204 No Content` - Resource deleted
- `400 Bad Request` - Invalid request
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Access denied
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation errors
- `500 Internal Server Error` - Server error

## Support

For API support, contact: saf@mitre.org