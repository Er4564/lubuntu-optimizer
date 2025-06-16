#!/bin/bash

echo "=== Fixing 'failed to fork' errors on low-RAM systems ==="

# 1. Check current memory
echo -e "\n[INFO] Current memory status:"
free -h

# 2. Add 2GB swap file if not already present
SWAPFILE="/swapfile"
if swapon --show | grep -q "$SWAPFILE"; then
    echo "[OK] Swap file already exists."
else
    echo "[ACTION] Creating 2GB swap file..."
    sudo fallocate -l 2G $SWAPFILE || sudo dd if=/dev/zero of=$SWAPFILE bs=1M count=2048
    sudo chmod 600 $SWAPFILE
    sudo mkswap $SWAPFILE
    sudo swapon $SWAPFILE
    echo "[OK] Swap file activated."

    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "[INFO] Making swap permanent..."
        echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
    fi
fi

# 3. Set higher ulimit (temporary for current session)
echo -e "\n[INFO] Setting user process limit (ulimit) higher for this session..."
ulimit -u 4096
ulimit -n 1024
echo "[OK] ulimit values updated."

# 4. Kill zombie processes
echo -e "\n[INFO] Searching for zombie processes..."
ZOMBIES=$(ps -e -o stat,pid | awk '$1 ~ /^Z/ { print $2 }')

if [[ -z "$ZOMBIES" ]]; then
    echo "[OK] No zombie processes found."
else
    echo "[ACTION] Found zombie processes: $ZOMBIES"
    echo "[INFO] Attempting to clean them (will signal parents)..."
    for pid in $ZOMBIES; do
        ppid=$(ps -o ppid= -p $pid)
        echo "[INFO] Sending SIGCHLD to parent process $ppid"
        sudo kill -CHLD $ppid
    done
fi

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
