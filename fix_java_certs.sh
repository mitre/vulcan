#!/bin/bash

set -e

echo "🔧 Fixing Java SSL certificates for MITRE corporate network"
echo "=========================================================="

OKTA_DOMAIN="trial-8371755.okta.com"
TEMP_DIR="/tmp/mitre_certs"
JAVA_CACERTS_PATH=$(keytool -printcert -file /dev/null 2>&1 | grep -o '/.*cacerts' | head -1 2>/dev/null || echo "/Library/Java/JavaVirtualMachines/*/Contents/Home/lib/security/cacerts")

echo "📍 Target domain: $OKTA_DOMAIN"
echo "📁 Java cacerts location: $JAVA_CACERTS_PATH"

# Create temp directory
mkdir -p "$TEMP_DIR"

echo ""
echo "🔍 Step 1: Extracting certificate chain from $OKTA_DOMAIN..."

# Get the complete certificate chain
echo "   Connecting to $OKTA_DOMAIN:443..."
if ! openssl s_client -connect "$OKTA_DOMAIN:443" -showcerts -servername "$OKTA_DOMAIN" < /dev/null > "$TEMP_DIR/chain.txt" 2>&1; then
    echo "❌ Failed to connect to $OKTA_DOMAIN"
    echo "🔍 Debugging info:"
    echo "   - Can you reach https://$OKTA_DOMAIN in browser?"
    echo "   - Corporate firewall blocking SSL handshake?"
    echo "   - Proxy configuration needed?"
    exit 1
fi

# Check if we got any certificates
if ! grep -q "BEGIN CERTIFICATE" "$TEMP_DIR/chain.txt"; then
    echo "❌ No certificates found in response"
    echo "🔍 Response content:"
    head -20 "$TEMP_DIR/chain.txt"
    exit 1
fi

# Extract individual certificates
awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' "$TEMP_DIR/chain.txt" | \
split -p '-----BEGIN CERTIFICATE-----' - "$TEMP_DIR/cert"

echo "📋 Step 2: Analyzing certificate chain..."

# Check what certificates we extracted
cert_count=$(ls "$TEMP_DIR"/cert* 2>/dev/null | wc -l | tr -d ' ')
echo "   Found $cert_count certificates in chain"

for cert_file in "$TEMP_DIR"/cert*; do
    if [ -s "$cert_file" ]; then
        subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/subject=//')
        echo "   📜 Certificate: $subject"
    fi
done

echo ""
echo "🔐 Step 3: Importing certificates into Java truststore..."

# Import each certificate
cert_num=1
for cert_file in "$TEMP_DIR"/cert*; do
    if [ -s "$cert_file" ]; then
        subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/subject=//')

        # Create alias from subject
        alias_name=$(echo "$subject" | sed -e 's/.*CN=\([^,]*\).*/\1/' -e 's/ /-/g' -e 's/\*/-wildcard/g' | tr '[:upper:]' '[:lower:]')

        echo "   ➕ Importing: $alias_name"

        # Check if already exists
        if keytool -list -cacerts -storepass changeit -alias "$alias_name" >/dev/null 2>&1; then
            echo "      ⚠️  Certificate already exists, skipping"
        else
            if sudo keytool -import -alias "$alias_name" -file "$cert_file" -cacerts -storepass changeit -noprompt 2>/dev/null; then
                echo "      ✅ Successfully imported"
            else
                echo "      ❌ Failed to import"
            fi
        fi
    fi
    ((cert_num++))
done

echo ""
echo "🧪 Step 4: Testing Okta CLI connection..."

# Clear any existing Java options that might interfere
unset JAVA_TOOL_OPTIONS

# Test the connection
if okta apps >/dev/null 2>&1; then
    echo "✅ SUCCESS! Okta CLI can now connect to $OKTA_DOMAIN"
    echo ""
    echo "🎉 Java certificate store is now properly configured for MITRE network"
    echo "   You can now use the Okta CLI for application management"
else
    echo "❌ FAILED: Okta CLI still cannot connect"
    echo ""
    echo "🔍 Additional troubleshooting options:"
    echo "   1. Check if you need to authenticate: okta login"
    echo "   2. Verify network connectivity to $OKTA_DOMAIN"
    echo "   3. Check corporate firewall/proxy settings"
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "🧹 Cleanup completed"