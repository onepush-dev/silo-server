# Railway packaging of the official, unmodified Silo omnibus image (build-2069).
# Adds a same-container gate (Node, already in the image) that keeps the public
# port closed until the first administrator has been created from the
# per-deploy generated credentials, so nobody else can claim first-run setup.
FROM ghcr.io/silo-server/silo-server:build-2069@sha256:4135ad1c1177228be9cdcf4aa44df3442148ba1d6eec6c96268679601a10ad63

COPY railway/gate.js /opt/railway/gate.js
COPY railway/bootstrap.sh /opt/railway/bootstrap.sh
COPY railway/entrypoint.sh /opt/railway/entrypoint.sh
COPY railway/s6/ /etc/s6-overlay/s6-rc.d/
RUN chmod 0755 /opt/railway/*.sh /etc/s6-overlay/s6-rc.d/svc-railway-*/run && \
    touch /etc/s6-overlay/user-bundles.d/user/contents.d/svc-railway-gate \
          /etc/s6-overlay/user-bundles.d/user/contents.d/svc-railway-bootstrap

# Railway has no NET_ADMIN and no host /proc mounts: turn TCP tuning off and
# give the bundled PostgreSQL an explicit memory budget.
ENV ENABLE_REDIS=true \
    ENABLE_MEILISEARCH=false \
    SILO_NET_TCP_CONGESTION=off \
    SILO_NET_TCP_SEND_BUFFER=off \
    POSTGRES_TUNE_MEMORY=2GB \
    TZ=Etc/UTC \
    SILO_INTERNAL_PORT=8081 \
    GATE_PORT=8080 \
    SILO_ADMIN_USERNAME=admin \
    SILO_ADMIN_EMAIL=admin@example.com

EXPOSE 8080
ENTRYPOINT ["/opt/railway/entrypoint.sh"]
