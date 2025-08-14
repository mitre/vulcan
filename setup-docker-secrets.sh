#!/bin/bash

# setup-docker-secrets.sh - Generate secure secrets for Vulcan Docker deployment
# This script creates a .env file with secure random values for production use

set -e

echo "========================================"
echo "Vulcan Docker Secrets Setup"
echo "========================================"
echo

# Check if .env already exists
if [ -f .env ]; then
    echo "⚠️  WARNING: .env file already exists!"
    echo
    read -p "Do you want to regenerate ALL secrets? This will overwrite your existing .env file (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env file. Exiting."
        exit 0
    fi
    echo "Backing up existing .env to .env.backup..."
    cp .env .env.backup
fi

# Check if we should use production or development template
echo "Which environment are you setting up?"
echo "1) Development (with test Okta)"
echo "2) Production"
read -p "Enter choice (1 or 2): " ENV_CHOICE

if [ "$ENV_CHOICE" = "1" ]; then
    TEMPLATE=".env.example"
    echo "Using development template..."
else
    TEMPLATE=".env.production.example"
    echo "Using production template..."
fi

if [ ! -f "$TEMPLATE" ]; then
    echo "❌ ERROR: Template file $TEMPLATE not found!"
    exit 1
fi

# Copy template
cp "$TEMPLATE" .env

# Generate secure secrets
echo "Generating secure secrets..."
POSTGRES_PASSWORD=$(openssl rand -hex 33)
SECRET_KEY_BASE=$(openssl rand -hex 64)
CIPHER_PASSWORD=$(openssl rand -hex 64)
CIPHER_SALT=$(openssl rand -hex 32)

# Replace placeholders based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env
    sed -i '' "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|" .env
    sed -i '' "s|^CIPHER_PASSWORD=.*|CIPHER_PASSWORD=$CIPHER_PASSWORD|" .env
    sed -i '' "s|^CIPHER_SALT=.*|CIPHER_SALT=$CIPHER_SALT|" .env
else
    # Linux
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env
    sed -i "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|" .env
    sed -i "s|^CIPHER_PASSWORD=.*|CIPHER_PASSWORD=$CIPHER_PASSWORD|" .env
    sed -i "s|^CIPHER_SALT=.*|CIPHER_SALT=$CIPHER_SALT|" .env
fi

# Set secure permissions
chmod 600 .env

echo
echo "✅ SUCCESS: .env file created with secure secrets!"
echo
echo "Next steps:"
if [ "$ENV_CHOICE" = "1" ]; then
    echo "1. The test Okta credentials are already configured"
    echo "2. Start the application with: docker-compose up"
    echo "3. Access Vulcan at: http://localhost:3000"
else
    echo "1. Edit .env and configure your OIDC/LDAP settings"
    echo "2. Update VULCAN_APP_URL with your production URL"
    echo "3. Configure SMTP settings if needed"
    echo "4. Place SSL certificates in ./certs/ if behind a corporate proxy"
    echo "5. Start the application with: docker-compose up -d"
fi
echo
echo "For more information, see README.md"