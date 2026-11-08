#!/command/with-contenv bash
# Creates the first Silo administrator from the per-deploy generated
# credentials, then opens the public gate. Runs once per container start.
set -uo pipefail
PORT="${PORT:-8081}"
BASE="http://127.0.0.1:${PORT}"
mkdir -p /run/railway-bootstrap && chmod 0755 /run/railway-bootstrap
mkdir -p /config/media && chown "${PUID:-911}:${PGID:-911}" /config/media 2>/dev/null || true

echo "[railway-bootstrap] waiting for Silo on ${BASE}"
until curl -q -fs -m 3 -o /dev/null "${BASE}/api/v1/health"; do sleep 3; done

status="$(curl -q -fs -m 10 "${BASE}/api/v1/auth/setup" || true)"
if echo "$status" | grep -q '"needs_setup":[[:space:]]*true'; then
  user="${SILO_ADMIN_USERNAME:-admin}"
  email="${SILO_ADMIN_EMAIL:-admin@example.com}"
  pass="${SILO_ADMIN_PASSWORD:-}"
  if [ -z "$pass" ]; then
    pass="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
    umask 077; printf '%s\n' "$pass" > /config/railway-admin-password
    echo "[railway-bootstrap] SILO_ADMIN_PASSWORD unset; generated one and saved it to /config/railway-admin-password"
  fi
  body="$(USER_="$user" EMAIL_="$email" PASS_="$pass" node -e 'process.stdout.write(JSON.stringify({username:process.env.USER_,email:process.env.EMAIL_,password:process.env.PASS_,create_default_profile:true,default_profile_name:process.env.USER_}))')"
  for i in $(seq 1 40); do
    code="$(curl -q -s -m 20 -o /tmp/railway-setup.out -w '%{http_code}' -H 'content-type: application/json' -X POST --data "$body" "${BASE}/api/v1/auth/setup")"
    if [ "$code" = "200" ] || [ "$code" = "201" ]; then
      echo "[railway-bootstrap] created administrator '${user}'"; break
    fi
    if curl -q -fs -m 10 "${BASE}/api/v1/auth/setup" | grep -q '"needs_setup":[[:space:]]*false'; then
      echo "[railway-bootstrap] setup already complete"; break
    fi
    echo "[railway-bootstrap] setup attempt $i returned HTTP $code: $(head -c 300 /tmp/railway-setup.out)"; sleep 5
  done
  rm -f /tmp/railway-setup.out
  if ! curl -q -fs -m 10 "${BASE}/api/v1/auth/setup" | grep -q '"needs_setup":[[:space:]]*false'; then
    echo "[railway-bootstrap] administrator could not be created; keeping the public port closed" >&2
    exec sleep infinity
  fi
else
  echo "[railway-bootstrap] administrator already exists"
fi
touch /run/railway-bootstrap/ready
echo "[railway-bootstrap] public port open"
exec sleep infinity
