#!/bin/bash

# Directory for certificates
CERT_DIR="certs"
CA_DIR="$CERT_DIR/ca"
DOMAIN_DIR="$CERT_DIR/domain"

# CA certificate files
CA_KEY="$CA_DIR/ca.key"
CA_CERT="$CA_DIR/ca.crt"

# Domain certificate files
DOMAIN_KEY="$DOMAIN_DIR/server.key"
DOMAIN_CSR="$DOMAIN_DIR/server.csr"
DOMAIN_CERT="$DOMAIN_DIR/server.crt"

# Certificate configuration
DAYS_VALID=365
KEY_BITS=4096
DOMAIN="localhost"

# Create directory structure
mkdir -p "$CA_DIR"
mkdir -p "$DOMAIN_DIR"

echo "=== Generating Certificate Authority (CA) ==="

# Generate CA private key
openssl genrsa -out "$CA_KEY" $KEY_BITS

# Generate self-signed CA certificate
openssl req -x509 -new -nodes \
    -key "$CA_KEY" \
    -sha256 -days $DAYS_VALID \
    -out "$CA_CERT" \
    -subj "/C=US/ST=State/L=City/O=Local CA/OU=Development/CN=Local Certificate Authority"

echo "=== Generating Server Certificate ==="

# Generate domain private key
openssl genrsa -out "$DOMAIN_KEY" $KEY_BITS

# Generate Certificate Signing Request (CSR)
openssl req -new \
    -key "$DOMAIN_KEY" \
    -out "$DOMAIN_CSR" \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=Development/CN=$DOMAIN"

# Create v3.ext file for SAN (Subject Alternative Names)
cat > "$DOMAIN_DIR/v3.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = www.$DOMAIN
DNS.3 = *.${DOMAIN}
EOF

# Sign the CSR with our CA
openssl x509 -req \
    -in "$DOMAIN_CSR" \
    -CA "$CA_CERT" \
    -CAkey "$CA_KEY" \
    -CAcreateserial \
    -out "$DOMAIN_CERT" \
    -days $DAYS_VALID \
    -sha256 \
    -extfile "$DOMAIN_DIR/v3.ext"

# Set appropriate permissions
chmod 600 "$CA_KEY" "$DOMAIN_KEY"
chmod 644 "$CA_CERT" "$DOMAIN_CERT"

# Clean up temporary files
rm -f "$DOMAIN_CSR" "$DOMAIN_DIR/v3.ext" "$CA_DIR/ca.srl"

echo "=== Certificate Generation Complete ==="
echo "CA Private Key: $CA_KEY"
echo "CA Certificate: $CA_CERT"
echo "Server Private Key: $DOMAIN_KEY"
echo "Server Certificate: $DOMAIN_CERT"
echo "Validity: $DAYS_VALID days"
echo "Key size: $KEY_BITS bits"
echo ""
echo "To trust this certificate, import the CA certificate ($CA_CERT) into your system's trust store."