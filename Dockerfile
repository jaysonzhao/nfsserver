FROM registry.access.redhat.com/ubi9/ubi:latest

# Install required packages
RUN dnf install -y nfs-utils hostname procps-ng && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create necessary directories and set permissions
RUN mkdir -p /exports && \
    mkdir -p /var/lib/nfs/rpc_pipefs && \
    mkdir -p /var/lib/nfs/v4recovery && \
    mkdir -p /var/run/rpcbind && \
    chmod 777 /exports

# Copy entrypoint script
COPY nfs-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/nfs-entrypoint.sh

# Expose ports
EXPOSE 2049/tcp 2049/udp 20048/tcp 20048/udp 111/tcp 111/udp

ENTRYPOINT ["/usr/local/bin/nfs-entrypoint.sh"]
