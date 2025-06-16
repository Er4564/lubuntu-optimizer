#!/bin/bash

# Script version and error handling
SCRIPT_VERSION="1.0.0"
set -e
trap 'echo "❌ Error occurred at line $LINENO"; exit 1' ERR

echo "🔧 Fork Issue Fix v$SCRIPT_VERSION"
echo "=== Fixing 'failed to fork' errors on low-RAM systems ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root: sudo $0"
    exit 1
fi

# 1. Check current memory
echo -e "\n[INFO] Current memory status:"
free -h

# 2. Add configurable swap file if not already present
SWAPFILE="/swapfile"
SWAP_SIZE=${SWAP_SIZE:-2G}

if swapon --show | grep -q "$SWAPFILE"; then
    echo "[OK] Swap file already exists."
else
    echo "[ACTION] Creating ${SWAP_SIZE} swap file..."
    
    # Check available disk space
    FREE_SPACE=$(df --output=avail / | tail -1)
    REQUIRED_SPACE=$((2 * 1024 * 1024)) # 2GB in KB
    
    if [ "$FREE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        echo "❌ Not enough disk space to create swap file. Free space: $(df -h / | tail -1 | awk '{print $4}')"
        exit 1
    fi
    
    # Create swap file with better error handling
    (sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=2048) && echo "✅ Swap file created" || {
        echo "❌ Failed to create swap file"
        exit 1
    }
    
    sudo chmod 600 "$SWAPFILE" && echo "✅ Swap file permissions set"
    sudo mkswap "$SWAPFILE" && echo "✅ Swap file formatted"
    sudo swapon "$SWAPFILE" && echo "✅ Swap file activated"

    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "[INFO] Making swap permanent..."
        echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
    fi
fi

# 3. Optimize system limits and memory management
echo -e "\n[INFO] Optimizing system limits and memory management..."

# Set higher ulimit for current session
ulimit -u 4096
ulimit -n 1024
echo "[OK] ulimit values updated for current session."

# Optimize kernel parameters for low memory systems
echo "[ACTION] Applying kernel optimizations..."
cat > /tmp/fork_fix_sysctl.conf << 'EOF'
# Memory management optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=3
vm.dirty_background_ratio=1
vm.overcommit_memory=1
vm.overcommit_ratio=50

# Process and fork optimizations
kernel.pid_max=65536
kernel.threads-max=16384
EOF

sudo cp /tmp/fork_fix_sysctl.conf /etc/sysctl.d/99-fork-fix.conf
sudo sysctl -p /etc/sysctl.d/99-fork-fix.conf && echo "✅ Kernel parameters applied"

# Make ulimit changes permanent
echo "[ACTION] Making ulimit changes permanent..."
if ! grep -q "lubuntu-optimizer fork fix" /etc/security/limits.conf; then
    cat >> /etc/security/limits.conf << 'EOF'

# lubuntu-optimizer fork fix
* soft nproc 4096
* hard nproc 8192
* soft nofile 1024
* hard nofile 2048
root soft nproc unlimited
root hard nproc unlimited
EOF
    echo "✅ Permanent limits configured"
fi

# 4. Clean up processes and optimize performance
echo -e "\n[INFO] Cleaning up system processes..."

# Kill zombie processes
echo "[INFO] Searching for zombie processes..."
ZOMBIES=$(ps -e -o stat,pid | awk '$1 ~ /^Z/ { print $2 }')

if [[ -z "$ZOMBIES" ]]; then
    echo "[OK] No zombie processes found."
else
    echo "[ACTION] Found zombie processes: $ZOMBIES"
    echo "[INFO] Attempting to clean them (will signal parents)..."
    for pid in $ZOMBIES; do
        ppid=$(ps -o ppid= -p $pid 2>/dev/null || echo "")
        if [[ -n "$ppid" && "$ppid" != "0" ]]; then
            echo "[INFO] Sending SIGCHLD to parent process $ppid"
            sudo kill -CHLD $ppid 2>/dev/null || echo "[WARN] Could not signal parent $ppid"
        fi
    done
fi

# Clean up system cache
echo "[ACTION] Cleaning system cache..."
sync
echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
echo "[OK] System cache cleared."

# 5. Summary
echo -e "\n[SUMMARY]"
free -h
swapon --show
ulimit -a | grep 'max user processes'

echo -e "\n[NOTE] To make higher ulimit permanent, edit these files:"
echo "- /etc/security/limits.conf"
echo "- /etc/systemd/user.conf or /etc/systemd/system.conf (DefaultTasksMax=infinity)"
echo "- And make sure pam_limits.so is included in /etc/pam.d/common-session"

echo -e "\n✅ Done. You may need to reboot for all changes to take full effect."
