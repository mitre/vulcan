#!/bin/bash

set -e

echo "🔧 Complete Java SSL certificate fix for MITRE corporate network"
echo "================================================================="

OKTA_DOMAIN="trial-8371755.okta.com"
CERT_FILE="okta.com.pem"

echo "📍 Target domain: $OKTA_DOMAIN"
echo "📄 Certificate file: $CERT_FILE"

# Check if the certificate file exists
if [ ! -f "$CERT_FILE" ]; then
    echo "❌ Certificate file $CERT_FILE not found"
    echo "   Please export the certificate from browser and save as $CERT_FILE"
    exit 1
fi

echo ""
echo "🔍 Step 1: Analyzing your exported certificate..."

# Check what we have
subject=$(openssl x509 -in "$CERT_FILE" -noout -subject 2>/dev/null | sed 's/subject=//')
issuer=$(openssl x509 -in "$CERT_FILE" -noout -issuer 2>/dev/null | sed 's/issuer=//')

echo "   📜 Subject: $subject"
echo "   🏢 Issuer: $issuer"

# Extract the issuer CN for intermediate cert
intermediate_cn=$(echo "$issuer" | sed -n 's/.*CN=\([^,]*\).*/\1/p')
echo "   🔗 Intermediate needed: $intermediate_cn"

echo ""
echo "🔐 Step 2: Downloading MITRE intermediate certificate..."

# Download the MITRE intermediate certificate
intermediate_url="http://pki.mitre.org/${intermediate_cn// /%20}.crt"
echo "   📥 Downloading from: $intermediate_url"

if curl -s -o mitre-intermediate.crt "$intermediate_url"; then
    echo "   ✅ Downloaded intermediate certificate"
else
    echo "   ⚠️  Download failed, trying alternative method..."
    # Alternative: manually construct the intermediate cert name
    curl -s -o mitre-intermediate.crt "http://pki.mitre.org/MITRE%20Infosec%20RSA%202018.crt" || {
        echo "   ❌ Cannot download intermediate certificate"
        echo "   Manual step needed: Export 'MITRE Infosec RSA 2018' certificate from browser"
        exit 1
    }
fi

echo ""
echo "🔐 Step 3: Importing certificates into Java truststore..."

# Import the intermediate certificate first
echo "   ➕ Importing intermediate certificate..."
if keytool -list -cacerts -storepass changeit -alias mitre-infosec-2018 >/dev/null 2>&1; then
    echo "      ⚠️  Intermediate certificate already exists"
else
    if sudo keytool -importcert -file mitre-intermediate.crt -alias mitre-infosec-2018 -cacerts -storepass changeit -noprompt 2>/dev/null; then
        echo "      ✅ Successfully imported intermediate certificate"
    else
        echo "      ❌ Failed to import intermediate certificate"
        exit 1
    fi
fi

# Import the end certificate (Okta)
echo "   ➕ Importing Okta certificate..."
if keytool -list -cacerts -storepass changeit -alias okta-end-cert >/dev/null 2>&1; then
    echo "      ⚠️  Okta certificate already exists"
else
    if sudo keytool -importcert -file "$CERT_FILE" -alias okta-end-cert -cacerts -storepass changeit -noprompt 2>/dev/null; then
        echo "      ✅ Successfully imported Okta certificate"
    else
        echo "      ❌ Failed to import Okta certificate"
        exit 1
    fi
fi

echo ""
echo "🧪 Step 4: Testing Okta CLI connection..."

# Clear any Java options that might interfere
unset JAVA_TOOL_OPTIONS

echo "   🔌 Testing connection to $OKTA_DOMAIN..."

if okta apps >/dev/null 2>&1; then
    echo "   ✅ SUCCESS! Okta CLI is now working"
    echo ""
    echo "🎉 Certificate chain complete! You can now use:"
    echo "   • okta apps list"
    echo "   • okta apps update <app-id>"
    echo "   • okta login (if authentication needed)"
else
    echo "   ❌ Still failing. Let's check what's missing..."
    echo ""
    echo "🔍 Verification steps:"
    echo "   1. Check imported certificates:"
    keytool -list -cacerts -storepass changeit | grep -E "mitre|okta"
    echo ""
    echo "   2. Try with authentication:"
    echo "      okta login"
    echo ""
    echo "   3. Check verbose output:"
    echo "      okta apps --verbose"
fi

# Cleanup
rm -f mitre-intermediate.crt

echo ""
echo "🧹 Cleanup completed"