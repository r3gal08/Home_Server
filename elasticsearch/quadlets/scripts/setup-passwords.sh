#!/bin/bash
set -e

#
# Elasticsearch Password Setup
# Runs as a oneshot after es01 is healthy.
# Sets the kibana_system user password so Kibana can authenticate.
#

echo "Waiting for Elasticsearch availability..."
until curl -s --cacert config/certs/ca/ca.crt https://es01:9200 | grep -q "missing authentication credentials"; do
  echo "  Elasticsearch not ready yet, retrying in 30s..."
  sleep 30
done

echo "Elasticsearch is up. Setting kibana_system password..."
until curl -s -X POST \
  --cacert config/certs/ca/ca.crt \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -H "Content-Type: application/json" \
  https://es01:9200/_security/user/kibana_system/_password \
  -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do
  echo "  Password API not ready yet, retrying in 10s..."
  sleep 10
done

echo "All done! kibana_system password configured."

