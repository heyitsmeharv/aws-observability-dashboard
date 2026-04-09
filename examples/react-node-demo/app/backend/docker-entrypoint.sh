#!/bin/sh
set -e

# The current demo image no longer uses this wrapper. Tracing now targets an
# in-task CloudWatch agent sidecar via localhost endpoints configured in the
# ECS task definition.
exec "$@"
