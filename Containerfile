# OMA Lightspeed - AI Assistant for Migration Planner
# Consumer repository pattern: thin wrapper over lightspeed-stack base image
#
# This image uses the standard Lightspeed Core Stack and injects OMA-specific
# configuration at runtime via ConfigMaps/volumes.

# Pin to specific digest for reproducible builds
# This is lightspeed-stack:0.3.1
FROM quay.io/lightspeed-core/lightspeed-stack@sha256:2f0ffece8209d763a50a0e49f57b8c372967551fbf821c735a5daf007139b66a

# Copy migration script (runs before lightspeed-stack starts)
COPY migrate.py /app/migrate.py

# Run migrations then start lightspeed-stack
ENTRYPOINT ["/bin/sh", "-c", "python3.12 /app/migrate.py && python3.12 src/lightspeed_stack.py"]

USER 1001

EXPOSE 8080

LABEL com.redhat.component="oma-lightspeed" \
      name="oma-lightspeed" \
      description="AI assistant for OMA Migration Planner" \
      io.k8s.description="AI assistant for OMA Migration Planner - helps users analyze migration sources and assessments" \
      distribution-scope="public" \
      release="main" \
      version="latest" \
      url="https://github.com/kubev2v/oma-lightspeed" \
      vendor="Red Hat, Inc."
