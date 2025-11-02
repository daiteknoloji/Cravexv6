# Railway Dockerfile for Matrix Synapse
FROM matrixdotorg/synapse:latest

# Set working directory
WORKDIR /data

# Copy config template
COPY synapse-config/homeserver.yaml /data/homeserver.yaml

# Create startup script
RUN printf '#!/bin/bash\n\
set -e\n\
echo "Starting Matrix Synapse..."\n\
exec python -m synapse.app.homeserver -c /data/homeserver.yaml\n' > /start.sh \
    && chmod +x /start.sh

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8008/health || exit 1

EXPOSE 8008

# Use bash directly
ENTRYPOINT ["/bin/bash"]
CMD ["/start.sh"]

