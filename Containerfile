# OMA Lightspeed - AI Assistant for Migration Planner
# Consumer repository pattern: thin wrapper over lightspeed-stack base image
#
# This image uses the standard Lightspeed Core Stack and injects OMA-specific
# configuration at runtime via ConfigMaps/volumes.

FROM registry.redhat.io/lightspeed-core/lightspeed-stack-rhel9:0.5.1

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
