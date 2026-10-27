#!/bin/bash
set -e

#
# Elasticsearch TLS Certificate Generator
# Runs as a oneshot init container before es01 starts.
# Idempotent — skips generation if certs already exist on the volume.
#

# ------- Validate passwords are set -------
if [ -z "${ELASTIC_PASSWORD}" ]; then
  echo "ERROR: ELASTIC_PASSWORD is not set in elastic.env"
  exit 1
fi

if [ -z "${KIBANA_PASSWORD}" ]; then
  echo "ERROR: KIBANA_PASSWORD is not set in elastic.env"
  exit 1
fi

# ------- Generate CA -------
if [ ! -f config/certs/ca.zip ]; then
  echo "Creating CA..."
  bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip
  unzip config/certs/ca.zip -d config/certs
else
  echo "CA already exists, skipping."
fi

# ------- Generate node, kibana & fleet-server certificates -------
if [ ! -f config/certs/certs.zip ]; then
  echo "Creating instance certificates..."
  cat > config/certs/instances.yml <<'INSTANCES'
instances:
  - name: es01
    dns:
      - es01
      - localhost
    ip:
      - 127.0.0.1
      - 192.168.2.56
  - name: kibana
    dns:
      - kibana
      - localhost
    ip:
      - 127.0.0.1
      - 192.168.2.56
  - name: fleet-server
    dns:
      - fleet-server
      - localhost
    ip:
      - 127.0.0.1
      - 192.168.2.56
INSTANCES

  bin/elasticsearch-certutil cert --silent --pem \
    -out config/certs/certs.zip \
    --in config/certs/instances.yml \
    --ca-cert config/certs/ca/ca.crt \
    --ca-key config/certs/ca/ca.key

  unzip config/certs/certs.zip -d config/certs
else
  echo "Instance certificates already exist, skipping."
fi

# ------- Set container permissions -------
echo "Setting file permissions..."
chown -R root:root config/certs
find config/certs -type d -exec chmod 750 {} \;
find config/certs -type f -exec chmod 640 {} \;

# ------- Export Fleet Server & CA certificates to host (hypervisor) -------
if [ -d /fleet-certs ]; then
  echo "Exporting fleet-server and CA certificates to host..."
  mkdir -p /fleet-certs/fleet-server
  cp -f config/certs/ca/ca.crt /fleet-certs/ca.crt
  cp -f config/certs/fleet-server/fleet-server.crt /fleet-certs/fleet-server/fleet-server.crt
  cp -f config/certs/fleet-server/fleet-server.key /fleet-certs/fleet-server/fleet-server.key
  chmod 644 /fleet-certs/ca.crt /fleet-certs/fleet-server/fleet-server.crt
  chmod 600 /fleet-certs/fleet-server/fleet-server.key
  echo "Export complete: ca.crt, fleet-server.crt, and fleet-server.key copied to host."
fi

echo "Certificate setup complete!"

