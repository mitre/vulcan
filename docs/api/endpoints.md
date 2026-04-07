# API Endpoints

## Overview

Vulcan provides JSON API endpoints for programmatic access to projects, components, STIGs, and SRGs. Most endpoints require authentication. Public endpoints (`/api/version`, `/health_check`) are noted below.

## Authentication

See [Authentication](authentication.md) for details on API authentication methods.

## Base URL

```
https://your-vulcan-instance.com
```

## Endpoints

### Version

#### Get Application Version
```http
GET /api/version
```

Returns application metadata. **No authentication required** — used by monitoring tools, deployment verification, and the frontend.

**Response:**
```json
{
  "name": "Vulcan",
  "version": "2.3.1",
  "rails": "8.0.4",
  "ruby": "3.4.9",
  "environment": "production"
}
```

### Health Check

#### Readiness Probe
```http
GET /health_check
```

Returns `ok (vulcan 2.3.1)` when database is connected. **No authentication required.**

#### Database Check
```http
GET /health_check/database
```

Returns `ok (vulcan 2.3.1)` when database is reachable.

#### Liveness Probe
```http
GET /up
```

Rails 8 built-in liveness probe. Returns 200 with no body. **No authentication required.**

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
POST /projects/:project_id/components.json
```

Creates a new component within a project.

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

JSON responses use flat structures (no wrapper object):

### Success Response
```json
{
  "id": 1,
  "name": "Example Project",
  "description": "..."
}
```

### Error Response
```json
{
  "error": "Not found"
}
```

### Toast Response (from mutation actions)
```json
{
  "toast": {
    "title": "Error",
    "message": "Validation failed",
    "variant": "danger"
  }
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

Rate limiting is enforced via rack-attack:
- Login attempts: 5 per minute per IP, 5 per minute per email
- File uploads: 10 per minute per IP

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