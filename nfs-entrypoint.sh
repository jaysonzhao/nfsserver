# Test review
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

# Configure NFSv4-specific settings with performance tuning
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
threads=16

[mountd]
port=20048

[exportd]
cache-use-ipaddr=y

[gssd]
use-memcache=y
EOF

# Configure exports for NFSv4 with performance options
cat > /etc/exports << EOF
/exports        *(rw,sync,no_root_squash,no_subtree_check,insecure,fsid=0,no_wdelay)
EOF

# Mount rpc_pipefs
mount -t rpc_pipefs sunrpc /var/lib/nfs/rpc_pipefs

# Start rpcbind daemon with IPv4 only
/usr/sbin/rpcbind -w 

# Start NFS services with more threads for large file handling
/usr/sbin/rpc.nfsd -V 4 -N 3 16  # 16 threads instead of default 8

# Start mountd in background
/usr/sbin/rpc.mountd -N 3 -V 4 --port 20048 -H 127.0.0.1 &

# Export the filesystems (avoid -r flag for large directories)
echo "Exporting filesystems (this may take time with large directories)..."
timeout 300 /usr/sbin/exportfs -av || {
  echo "Export timeout reached, continuing with basic export..."
  /usr/sbin/exportfs -a
}

# Show initial debug information
echo "=== Displaying exports ==="
/usr/sbin/exportfs -v | head -20  # Limit output for large exports
echo "=== Directory sample ==="
ls -la /exports | head -10
echo "=== RPC Info ==="
rpcinfo -p
echo "=== Process Status ==="
ps aux | grep -E "nfsd|mountd|rpcbind"

# Function to perform maintenance
perform_maintenance() {
  echo "=== Performing NFS maintenance ($(date)) ==="
  
  # Use -a instead of -rav to avoid full re-scan
  /usr/sbin/exportfs -a
  
  # Check if services are still running
  if ! pgrep rpc.nfsd > /dev/null; then
    echo "NFS daemon died, restarting..."
    /usr/sbin/rpc.nfsd -V 4 -N 3 16
  fi
  
  if ! pgrep rpc.mountd > /dev/null; then
    echo "Mount daemon died, restarting..."
    /usr/sbin/rpc.mountd -N 3 -V 4 --port 20048 -H 127.0.0.1 &
  fi
  
  # Show abbreviated status
  echo "Active exports: $(/usr/sbin/exportfs -v | wc -l)"
  ps aux | grep -E "nfsd|mountd|rpcbind" | grep -v grep
}

# Keep the container running with less frequent updates for large filesystems
while true; do
  sleep 43200  # 12 hours instead of 6 for large filesystems
  perform_maintenance
done
