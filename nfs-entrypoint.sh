#!/bin/bash
set -ex

# Create necessary directories
mkdir -p /exports
chmod 777 /exports
mkdir -p /var/lib/nfs/v4recovery
mkdir -p /var/lib/nfs/rpc_pipefs
mkdir -p /var/lib/nfs/nfsd
mkdir -p /run/rpcbind

# Create test file
echo "NFSv4 Server is working" > /exports/test.txt

# Configure NFSv4-specific settings
cat > /etc/nfs.conf << EOF
[nfsd]
udp=n
tcp=y
vers3=n
vers4=y
vers4.0=y
vers4.1=y
vers4.2=y
host=0.0.0.0

[mountd]
port=20048
EOF

# Configure exports for NFSv4
cat > /etc/exports << EOF
/exports        *(rw,sync,no_root_squash,no_subtree_check,insecure,fsid=0)
EOF

# Mount rpc_pipefs
mount -t rpc_pipefs sunrpc /var/lib/nfs/rpc_pipefs

# Start rpcbind daemon with IPv4 only
/usr/sbin/rpcbind -w 

# Start NFS services
/usr/sbin/rpc.nfsd -V 4 -N 3 
/usr/sbin/rpc.mountd -N 3 -V 4 --port 20048 -H 127.0.0.1 --foreground &

# Export the filesystems
/usr/sbin/exportfs -rav

# Show initial debug information
echo "=== Displaying exports ==="
/usr/sbin/exportfs -v
echo "=== Directory contents ==="
ls -la /exports
echo "=== RPC Info ==="
rpcinfo -p
echo "=== Process Status ==="
ps aux | grep -E "nfsd|mountd|rpcbind"

# Keep the container running with status updates every 6 hours
while true; do
  sleep 21600  # 6 hours = 6 * 3600 seconds
  /usr/sbin/exportfs -ra
  echo "=== Current exports and status ($(date)) ==="
  /usr/sbin/exportfs -v
  ps aux | grep -E "nfsd|mountd|rpcbind"
  rpcinfo -p
done
