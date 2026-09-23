#!/bin/bash

DOMAIN=$1
EMAIL=$2

# Install acme.sh for SSL certificates
curl https://get.acme.sh | sh
source ~/.bashrc

# Set default CA to Let's Encrypt
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# Register account
~/.acme.sh/acme.sh --register-account -m "$EMAIL"

# Issue certificate
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone

# Install certificate
mkdir -p /etc/afterlifevpn/cert
~/.acme.sh/acme.sh --installcert -d "$DOMAIN" \
    --key-file /etc/afterlifevpn/cert/private.key \
    --fullchain-file /etc/afterlifevpn/cert/fullchain.crt

# Set up auto-renewal
~/.acme.sh/acme.sh --upgrade --auto-upgrade

echo "SSL certificate installed for $DOMAIN"
