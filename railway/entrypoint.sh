#!/bin/sh
# Silo listens on an internal loopback-only port; the gate owns the public one.
export PORT="${SILO_INTERNAL_PORT:-8081}"
export GATE_PORT="${GATE_PORT:-8080}"
exec /init "$@"
