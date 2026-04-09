#!/bin/sh
set -e

if [ "${OTEL_AWS_APPLICATION_SIGNALS_ENABLED:-false}" = "true" ] && [ -z "${CW_CONTAINER_IP:-}" ]; then
  TOKEN="$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)"

  if [ -n "$TOKEN" ]; then
    CW_CONTAINER_IP="$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/local-ipv4" || true)"
  else
    CW_CONTAINER_IP="$(curl -fsS "http://169.254.169.254/latest/meta-data/local-ipv4" || true)"
  fi

  if [ -n "$CW_CONTAINER_IP" ]; then
    export CW_CONTAINER_IP
    export OTEL_AWS_APPLICATION_SIGNALS_EXPORTER_ENDPOINT="${OTEL_AWS_APPLICATION_SIGNALS_EXPORTER_ENDPOINT:-http://${CW_CONTAINER_IP}:4316/v1/metrics}"
    export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="${OTEL_EXPORTER_OTLP_TRACES_ENDPOINT:-http://${CW_CONTAINER_IP}:4316/v1/traces}"
    export OTEL_TRACES_SAMPLER_ARG="${OTEL_TRACES_SAMPLER_ARG:-endpoint=http://${CW_CONTAINER_IP}:2000}"
  else
    echo "warning: unable to resolve CW_CONTAINER_IP from instance metadata; tracing endpoints were not configured" >&2
  fi
fi

exec "$@"
