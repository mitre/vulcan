# SSL Certificates Directory

This directory is for custom SSL certificates needed during Docker builds, particularly for corporate proxy environments.

## Usage

1. Place your certificate files (`.crt`, `.pem`, etc.) in this directory
2. The Docker build process will automatically copy and install these certificates
3. Certificates in this directory are ignored by git (except this README)

## Example

For MITRE corporate proxy:
```bash
cp ~/.aws/mitre-ca-bundle.pem ./certs/
docker build .
```

## Security Note

- Never commit certificates to version control
- Only place certificates here temporarily for Docker builds
- Remove certificates after building if they contain sensitive information

## Supported Formats

- `.crt` - Certificate files
- `.pem` - PEM formatted certificates
- `.cer` - DER or Base64 encoded certificates

All certificates placed here will be:
1. Copied to `/usr/local/share/ca-certificates/` in the container
2. Added to the system certificate store via `update-ca-certificates`
3. Available for all HTTPS connections within the container