#!/bin/bash

if [ -f .env ]; then
	echo ".env already exists, if you would like to regenerate your secrets, please delete this file and re-run the script."
else
	echo ".env does not exist, creating..."
	(umask 066; touch .env)
fi

if ! grep -qF "POSTGRES_PASSWORD" .env; then
	echo ".env does not contain POSTGRES_PASSWORD, generating secret..."
	echo -e "\nPOSTGRES_PASSWORD=$(openssl rand -hex 33)" >> .env
fi


if [ -f .env-prod ]; then
	echo ".env-prod already exists, if you would like to regenerate your secrets, please delete this file and re-run the script."
else
	echo ".env-prod does not exist, creating..."
	cat >.env-prod - << EOF
SECRET_KEY_BASE=$(openssl rand -hex 64)
CIPHER_PASSWORD=$(openssl rand -hex 64)
CIPHER_SALT=$(openssl rand -hex 32)
EOF
fi

echo "Done"
