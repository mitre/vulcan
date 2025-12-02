# Search Abbreviations System

## Overview

The search abbreviation system allows flexible matching of common security terminology abbreviations. When a user searches for "RHEL", the system expands this to also search for "Red Hat Enterprise Linux".

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  ABBREVIATION SOURCES (Merged, User > Core)                     │
├─────────────────────────────────────────────────────────────────┤
│  1. User additions (database, admin UI)                         │
│     └── Can ADD new abbreviations                               │
│     └── Can OVERRIDE core if needed                             │
│                                                                 │
│  2. Core defaults (codebase, MITRE maintains)                   │
│     └── Ships with Vulcan, updated each release                 │
│     └── Common security/OS abbreviations                        │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
User types "RHEL" in Command Palette
        │
        ▼
┌───────────────────────────────┐
│  SearchAbbreviationService    │
│  - Load core abbreviations    │
│  - Load user abbreviations    │
│  - Merge (user overrides)     │
│  - Cache result               │
└───────────────────────────────┘
        │
        ▼
Query expanded: "RHEL" + "Red Hat Enterprise Linux"
        │
        ▼
pg_search finds matches for both terms
```

## Core Abbreviations (MITRE Maintained)

Located in `config/search_abbreviations.yml`:

```yaml
# Core abbreviations - updated with each Vulcan release
# Users can override or add to these via Admin UI

abbreviations:
  # Linux Distributions
  RHEL: "Red Hat Enterprise Linux"
  SLES: "SUSE Linux Enterprise Server"
  OL: "Oracle Linux"
  RHCOS: "Red Hat CoreOS"
  CentOS: "CentOS"

  # Container/Cloud
  K8s: "Kubernetes"
  OCP: "OpenShift Container Platform"
  EKS: "Elastic Kubernetes Service"
  AKS: "Azure Kubernetes Service"
  GKE: "Google Kubernetes Engine"

  # Windows
  Win: "Windows"
  WinSrv: "Windows Server"

  # Databases
  MSSQL: "Microsoft SQL Server"
  PG: "PostgreSQL"

  # Network/Security
  FW: "Firewall"
  IDS: "Intrusion Detection System"
  IPS: "Intrusion Prevention System"
  SIEM: "Security Information and Event Management"

  # DISA/DoD
  STIG: "Security Technical Implementation Guide"
  SRG: "Security Requirements Guide"
  CCI: "Control Correlation Identifier"
  SCAP: "Security Content Automation Protocol"
```

## Database Schema

```ruby
# Migration: db/migrate/YYYYMMDDHHMMSS_create_search_abbreviations.rb

create_table :search_abbreviations do |t|
  t.string :abbreviation, null: false
  t.string :expansion, null: false
  t.references :created_by, foreign_key: { to_table: :users }
  t.boolean :active, default: true
  t.timestamps
end

add_index :search_abbreviations, :abbreviation, unique: true
add_index :search_abbreviations, :active
```

## Service Class

```ruby
# app/services/search_abbreviation_service.rb

class SearchAbbreviationService
  CACHE_KEY = 'search_abbreviations_merged'
  CACHE_TTL = 1.hour

  class << self
    # Get all abbreviations (core + user, merged)
    def all
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        core_abbreviations.merge(user_abbreviations)
      end
    end

    # Expand a query with abbreviation matches
    def expand_query(query)
      abbreviations = all
      expanded_terms = [query]

      # Check each word in query against abbreviations
      query.split(/\s+/).each do |word|
        if abbreviations[word.upcase]
          expanded_terms << abbreviations[word.upcase]
        end
      end

      expanded_terms.uniq
    end

    # Clear cache (call after user adds/updates abbreviations)
    def clear_cache!
      Rails.cache.delete(CACHE_KEY)
    end

    private

    def core_abbreviations
      config_path = Rails.root.join('config', 'search_abbreviations.yml')
      return {} unless File.exist?(config_path)

      YAML.load_file(config_path)['abbreviations'] || {}
    end

    def user_abbreviations
      SearchAbbreviation.active.pluck(:abbreviation, :expansion).to_h
    end
  end
end
```

## Deployment Options

### Docker

Mount custom abbreviations via volume:

```yaml
# docker-compose.yml
services:
  vulcan:
    volumes:
      - ./my-abbreviations.yml:/app/config/search_abbreviations.yml:ro
```

### Kubernetes

Use ConfigMap:

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vulcan-abbreviations
data:
  search_abbreviations.yml: |
    abbreviations:
      RHEL: "Red Hat Enterprise Linux"
      # ... your additions
```

```yaml
# deployment.yaml
volumes:
  - name: abbreviations
    configMap:
      name: vulcan-abbreviations
volumeMounts:
  - name: abbreviations
    mountPath: /app/config/search_abbreviations.yml
    subPath: search_abbreviations.yml
```

### Database Seeding

For bulk loading at deploy time:

```ruby
# db/seeds/search_abbreviations.rb

abbreviations = {
  'ACME' => 'ACME Corporation Internal',
  'PROJ1' => 'Project Alpha',
  # ... org-specific abbreviations
}

abbreviations.each do |abbrev, expansion|
  SearchAbbreviation.find_or_create_by!(abbreviation: abbrev) do |sa|
    sa.expansion = expansion
    sa.active = true
  end
end
```

## Admin UI

Admins can manage abbreviations at `/admin/search_abbreviations`:

- **View**: See all abbreviations (core + user, with source indicator)
- **Add**: Create new user abbreviation
- **Edit**: Modify user abbreviations (cannot edit core)
- **Delete**: Remove user abbreviations
- **Override**: User abbreviation with same key as core takes precedence

## API Endpoints

```
GET    /api/admin/search_abbreviations      # List all (core + user)
POST   /api/admin/search_abbreviations      # Create user abbreviation
PUT    /api/admin/search_abbreviations/:id  # Update user abbreviation
DELETE /api/admin/search_abbreviations/:id  # Delete user abbreviation
```

## Testing

```ruby
# spec/services/search_abbreviation_service_spec.rb

RSpec.describe SearchAbbreviationService do
  describe '.expand_query' do
    it 'expands RHEL to include full name' do
      result = described_class.expand_query('RHEL')
      expect(result).to include('RHEL')
      expect(result).to include('Red Hat Enterprise Linux')
    end

    it 'handles multiple abbreviations in query' do
      result = described_class.expand_query('RHEL K8s')
      expect(result).to include('Red Hat Enterprise Linux')
      expect(result).to include('Kubernetes')
    end

    it 'prioritizes user abbreviations over core' do
      create(:search_abbreviation, abbreviation: 'RHEL', expansion: 'Custom RHEL')
      described_class.clear_cache!

      result = described_class.expand_query('RHEL')
      expect(result).to include('Custom RHEL')
      expect(result).not_to include('Red Hat Enterprise Linux')
    end
  end
end
```

## Files

| File | Purpose |
|------|---------|
| `config/search_abbreviations.yml` | Core abbreviations (MITRE maintained) |
| `app/models/search_abbreviation.rb` | User abbreviations model |
| `app/services/search_abbreviation_service.rb` | Merge & expand logic |
| `app/controllers/api/admin/search_abbreviations_controller.rb` | Admin API |
| `app/javascript/pages/admin/SearchAbbreviationsPage.vue` | Admin UI |
