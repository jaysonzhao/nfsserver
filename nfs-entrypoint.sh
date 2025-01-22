#!/bin/bash
set -ex

# Create necessary directories
mkdir -p /exports
chmod 777 /exports

# Create a test file
echo "NFSv4 Server is working" > /exports/test.txt

# Configure NFSv4-specific settings
cat > /etc/nfs.conf << EOF
[nfsd]
vers4=y
vers4.0=y
vers4.1=y
vers4.2=y
tcp=y
udp=n
EOF

# Configure exports for NFSv4
cat > /etc/exports << EOF
/exports        *(rw,sync,no_root_squash,no_subtree_check,insecure,fsid=0)
EOF

# Create required NFS directories
mkdir -p /var/lib/nfs/rpc_pipefs
mkdir -p /var/lib/nfs/v4recovery
mkdir -p /var/lib/nfs/nfsd
mkdir -p /var/run/rpcbind

# Start rpcbind daemon
/usr/sbin/rpcbind -w

# Start required services
/usr/sbin/rpc.nfsd -V 4 -G 10
/usr/sbin/rpc.mountd -V 4 --no-udp --foreground &

# Export the filesystems
/usr/sbin/exportfs -rav

# Show debug information
echo "=== Displaying exports ==="
/usr/sbin/exportfs -v
echo "=== Directory contents ==="
ls -la /exports
echo "=== RPC Info ==="
rpcinfo -p

# Keep the container running
while true; do
  sleep 30
  /usr/sbin/exportfs -ra
  echo "=== Current exports and status ==="
  /usr/sbin/exportfs -v
  ps aux | grep -E "nfsd|mountd|rpcbind"
  rpcinfo -p
done
