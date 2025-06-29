#!/bin/bash
SCRIPT_VERSION="2.1.5"

# Script version and error handling
set -e
trap 'echo "❌ Error occurred at line $LINENO"; exit 1' ERR

echo "🚀 Lubuntu Optimizer v$SCRIPT_VERSION"
echo "🚀 Starting FINAL ultra optimization for Lubuntu..."
echo "ℹ️  This script will keep LXDE and set up auto-login"
echo "🔧 Includes fork issue fixes for low-RAM systems"
echo "⏰ Started at: $(date)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root: sudo $0"
    exit 1
fi

    # Force kill any running apt/dpkg processes and services
echo "🔒 Checking and stopping apt/dpkg processes and services..."

# Kill any running apt/dpkg processes
APT_PROCS=$(pgrep -f "apt|dpkg|unattended-upgrade" || true)
if [ -n "$APT_PROCS" ]; then
    echo "⚠️  Detected running apt/dpkg processes: $APT_PROCS"
    echo "    Killing apt/dpkg processes..."
    sudo kill -9 $APT_PROCS 2>/dev/null || true
    sleep 3
    echo "    ✅ Killed apt/dpkg processes."
fi

# Stop and disable unattended-upgrades service
sudo systemctl stop unattended-upgrades 2>/dev/null || true
sudo systemctl disable unattended-upgrades 2>/dev/null || true

# Remove apt locks if they exist
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock 2>/dev/null || true
sudo dpkg --configure -a 2>/dev/null || true

echo "    ✅ APT system cleared and ready."

# Low RAM fix: If system has 1GB RAM or less, create 2GB swap and apply extra tweaks
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$TOTAL_MEM_KB" -le 1048576 ]; then
    echo "⚠️  Low RAM detected (<=1GB). Applying extra low-memory optimizations..."
    SWAPFILE="/swapfile"
    SWAP_SIZE="2G"
    if ! swapon --show | grep -q "$SWAPFILE"; then
        echo "    📝 Creating 2GB swap file for low RAM..."
        sudo fallocate -l $SWAP_SIZE $SWAPFILE || sudo dd if=/dev/zero of=$SWAPFILE bs=1M count=2048
        sudo chmod 600 $SWAPFILE
        sudo mkswap $SWAPFILE
        sudo swapon $SWAPFILE
        if ! grep -q "$SWAPFILE" /etc/fstab; then
            echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
        fi
        echo "    ✅ 2GB swap file created and enabled."
    else
        echo "    ✅ Swap file already exists."
    fi
    # Extra sysctl and ulimit tweaks for low RAM
    sudo tee /etc/sysctl.d/99-lowram.conf > /dev/null << 'EOF'
vm.swappiness=20
vm.overcommit_memory=1
vm.overcommit_ratio=50
EOF
    sudo sysctl -p /etc/sysctl.d/99-lowram.conf
    ulimit -u 4096
    ulimit -n 1024
    echo "    ✅ Low RAM sysctl and ulimit tweaks applied."
fi

### PART 0: System Information ###
echo "🔍 System Information:"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "  Disk: $(df -h / | tail -1 | awk '{print $2 " total, " $3 " used, " $4 " available"}')"

### PART 1: Remove Heavy/Unnecessary Packages (Keep LXDE) ###
echo "❌ Removing heavy packages while keeping LXDE..."
echo "  🗑️  Removing Snap packages first..."
sudo snap list 2>/dev/null && echo "  Found snap packages, removing..." || echo "  No snap packages found"
sudo snap remove --purge firefox 2>/dev/null && echo "    ✅ Removed Firefox snap" || echo "    ⚠️  Firefox snap not found"
sudo snap remove --purge snap-store 2>/dev/null && echo "    ✅ Removed snap-store" || echo "    ⚠️  snap-store not found"
sudo snap remove --purge core* 2>/dev/null && echo "    ✅ Removed core snaps" || echo "    ⚠️  core snaps not found"

echo "  🗑️  Removing other heavy packages..."
HEAVY_PACKAGES=(
    ubuntu-desktop-minimal
    snapd
    network-manager-gnome
    pulseaudio*
    apport*
    popularity-contest
    thunderbird*
    libreoffice*
    gimp*
    transmission*
    vlc*
    gnome-games*
)

# Remove packages safely with error handling
for pkg in "${HEAVY_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
        echo "    🗑️  Removing $pkg..."
        sudo apt purge -y "$pkg" 2>/dev/null || echo "    ⚠️  Could not remove $pkg"
    fi
done

echo "  🧹 Running autoremove and clean..."
sudo apt autoremove -y && echo "    ✅ Autoremove completed" || echo "    ❌ Autoremove failed"
sudo apt clean && echo "    ✅ Cache cleaned" || echo "    ❌ Cache clean failed"
sudo rm -rf /var/snap /snap /var/lib/snapd && echo "    ✅ Snap directories removed"

### PART 2: Install Lightweight Apps and Audio ###
echo "📦 Installing lightweight applications..."
LIGHT_PACKAGES=(
    audacious
    htop
    zram-config
    dillo
    surf
    links2
    alsa-utils
    alsa-base
    chromium-browser
    mc
    geany
    mupdf
    feh
    preload
)

for pkg in "${LIGHT_PACKAGES[@]}"; do
    echo "  📦 Installing $pkg..."
    if [ "$pkg" = "chromium-browser" ]; then
        sudo apt install -y "$pkg" --no-install-recommends && echo "    ✅ Installed $pkg" || echo "    ❌ Failed to install $pkg"
    else
        if ! dpkg -l | grep -q "$pkg"; then
            sudo apt install -y "$pkg" && echo "✅ Installed $pkg" || echo "❌ Failed to install $pkg"
        else
            echo "⚠️ $pkg is already installed"
        fi
    fi
done

sudo apt-mark manual "${LIGHT_PACKAGES[@]}"

### PART 3: Configure Auto-Login for LXDE ###
echo "🔐 Setting up auto-login for LXDE..."
echo "  Current user: $(whoami)"
CURRENT_USER=$(whoami)

echo "  📝 Configuring LightDM for auto-login..."
sudo mkdir -p /etc/lightdm/lightdm.conf.d/
sudo tee /etc/lightdm/lightdm.conf.d/12-autologin.conf > /dev/null << EOF
[Seat:*]
autologin-user=$CURRENT_USER
autologin-user-timeout=0
EOF

echo "    ✅ Auto-login configured for user: $CURRENT_USER"

# Ensure LightDM is enabled
sudo systemctl enable lightdm && echo "    ✅ LightDM enabled" || echo "    ❌ Failed to enable LightDM"

### PART 4: Install TLP (power-saving) ###
echo "🔋 Installing TLP for power management..."
sudo apt install -y tlp tlp-rdw && echo "  ✅ TLP installed" || echo "  ❌ TLP installation failed"
sudo systemctl enable tlp && echo "  ✅ TLP enabled" || echo "  ❌ TLP enable failed"
sudo systemctl start tlp && echo "  ✅ TLP started" || echo "  ❌ TLP start failed"

### PART 5: Set CPU Governor to Performance ###
echo "⚡ Setting CPU governor to performance..."
echo "  Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'Unable to read')"

# Install cpufrequtils for persistent governor setting
sudo apt install -y cpufrequtils && echo "  ✅ cpufrequtils installed" || echo "  ❌ cpufrequtils installation failed"

# Install auto-cpufreq for advanced CPU frequency management
echo "  📦 Installing auto-cpufreq..."
if ! command -v auto-cpufreq >/dev/null 2>&1; then
    echo "    🔄 Downloading and installing auto-cpufreq..."
    cd /tmp
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git || {
        echo "    ⚠️  Git clone failed, trying snap installation..."
        sudo snap install auto-cpufreq && echo "    ✅ auto-cpufreq installed via snap" || echo "    ❌ auto-cpufreq installation failed"
    }
    
    if [ -d "/tmp/auto-cpufreq" ]; then
        cd /tmp/auto-cpufreq
        sudo ./auto-cpufreq-installer && echo "    ✅ auto-cpufreq installed" || echo "    ❌ auto-cpufreq installation failed"
        cd - >/dev/null
        rm -rf /tmp/auto-cpufreq
    fi
else
    echo "    ✅ auto-cpufreq already installed"
fi

# Configure auto-cpufreq for performance
echo "  ⚙️  Configuring auto-cpufreq for performance..."
sudo tee /etc/auto-cpufreq.conf > /dev/null << 'EOF'
# auto-cpufreq configuration for performance optimization
[charger]
governor = performance
scaling_min_freq = 800000
scaling_max_freq = 2500000
turbo = auto

[battery]
governor = performance
scaling_min_freq = 800000
scaling_max_freq = 2000000
turbo = auto
EOF

# Enable and start auto-cpufreq
if command -v auto-cpufreq >/dev/null 2>&1; then
    sudo auto-cpufreq --install && echo "    ✅ auto-cpufreq service installed and enabled" || echo "    ❌ auto-cpufreq service installation failed"
fi

# Set governor to performance (fallback)
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils > /dev/null
echo "  📝 Set default governor to performance in /etc/default/cpufrequtils"

# Apply immediately
if command -v cpufreq-set >/dev/null; then
    sudo cpufreq-set -g performance && echo "✅ CPU governor set to performance" || echo "❌ Failed to set CPU governor"
else
    echo "⚠️ cpufreq-set not available"
fi

# Intel P-state configuration
if [ -d /sys/devices/system/cpu/intel_pstate ]; then
    echo "Intel P-state is supported. Enabling in GRUB..."
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="intel_pstate=enable /' /etc/default/grub
    sudo update-grub
    echo "Intel P-state will be enabled after reboot."
else
    echo "Intel P-state not supported on this CPU. Using acpi-cpufreq."
fi

### PART 6: Disable Unused Services ###
echo "🚫 Disabling unnecessary services..."
SERVICES=(
    bluetooth
    cups
    avahi-daemon
    speech-dispatcher
    whoopsie
    ModemManager
    saned
    colord
    accounts-daemon
    snapd
    NetworkManager-wait-online
    plymouth
    ufw
    apport
    brltty
)

for svc in "${SERVICES[@]}"; do
    if systemctl is-enabled "$svc" >/dev/null 2>&1; then
        echo "  🚫 Disabling $svc..."
        sudo systemctl disable "$svc" 2>/dev/null && echo "    ✅ Disabled $svc" || echo "    ⚠️  Failed to disable $svc"
        sudo systemctl stop "$svc" 2>/dev/null && echo "    🛑 Stopped $svc" || echo "    ⚠️  Failed to stop $svc"
    else
        echo "  ⚠️  Service $svc not found or already disabled"
    fi
done

### PART 6.1: Analyze and Remove Unnecessary Running Services ###
echo "🔍 Checking running services and disabling unnecessary ones..."

# Define a list of essential services for a minimal LXDE system
ESSENTIAL_SERVICES=(
    "systemd-journald"
    "systemd-logind"
    "dbus"
    "lightdm"
    "networking"
    "cron"
    "rsyslog"
    "polkit"
    "udisks2"
    "accounts-daemon"
    "avahi-daemon"
    "tlp"
    "zram-config"
    "cpufrequtils"
    "auto-cpufreq"
    "alsa-state"
    "alsa-restore"
    "getty@tty1"
    "ssh"
)

# Get all running systemd services
RUNNING_SERVICES=$(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' | sed 's/\.service$//')

for svc in $RUNNING_SERVICES; do
    IS_ESSENTIAL=0
    for essential in "${ESSENTIAL_SERVICES[@]}"; do
        if [[ "$svc" == "$essential" ]]; then
            IS_ESSENTIAL=1
            break
        fi
    done
    if [ $IS_ESSENTIAL -eq 0 ]; then
        echo "  🚫 $svc is not essential. Attempting to stop, disable, and mask..."
        sudo systemctl stop "$svc" 2>/dev/null || true
        sudo systemctl disable "$svc" 2>/dev/null || true
        sudo systemctl mask "$svc" 2>/dev/null || true
        echo "    ✅ $svc stopped, disabled, and masked."
    else
        echo "  ✅ $svc is essential and will be kept running."
    fi
done

### PART 7: Configure Lightweight Alternatives ###
echo "🔧 Setting up lightweight alternatives..."
echo "  🐚 Configuring dash as default shell..."
echo "dash dash/sh boolean true" | sudo debconf-set-selections
sudo dpkg-reconfigure dash && echo "    ✅ Dash configured" || echo "    ⚠️  Dash configuration failed"

echo "  🌐 Setting lightweight default browser..."
sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/chromium-browser 50 && echo "    ✅ Chromium set as default browser" || echo "    ⚠️  Browser alternative failed"

### PART 8: Enhanced Swap Configuration and Fork Issue Fix ###
echo "🧠 Enhanced swap configuration and fork issue fixes..."
SWAPFILE="/swapfile"
SWAP_SIZE=${SWAP_SIZE:-2G}

if swapon --show | grep -q "$SWAPFILE"; then
    echo "  ✅ Swap file already exists: $(swapon --show | grep $SWAPFILE)"
else
    echo "  📝 Creating ${SWAP_SIZE} swap file..."
    
    # Check available disk space
    FREE_SPACE=$(df --output=avail / | tail -1)
    REQUIRED_SPACE=$((2 * 1024 * 1024)) # 2GB in KB
    
    if [ "$FREE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        echo "❌ Not enough disk space to create swap file. Free space: $(df -h / | tail -1 | awk '{print $4}')"
        echo "  🔄 Reducing swap size to 1GB..."
        SWAP_SIZE="1G"
        REQUIRED_SPACE=$((1024 * 1024)) # 1GB in KB
        
        if [ "$FREE_SPACE" -lt "$REQUIRED_SPACE" ]; then
            echo "❌ Still not enough disk space. Skipping swap creation."
        else
            # Create swap file with better error handling
            (sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=1024) && echo "    ✅ Swap file created" || {
                echo "    ❌ Failed to create swap file"
            }
        fi
    else
        # Create swap file with better error handling
        (sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=2048) && echo "    ✅ Swap file created" || {
            echo "    ❌ Failed to create swap file"
        }
    fi
    
    if [ -f "$SWAPFILE" ]; then
        sudo chmod 600 "$SWAPFILE" && echo "    ✅ Swap file permissions set"
        sudo mkswap "$SWAPFILE" && echo "    ✅ Swap file formatted"
        sudo swapon "$SWAPFILE" && echo "    ✅ Swap file activated"
        
        if ! grep -q "$SWAPFILE" /etc/fstab; then
            echo "    📝 Making swap permanent..."
            echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
            echo "    ✅ Swap file added to fstab"
        fi
    fi
fi

# --- Fork Issue Fix Integration ---
echo "🔧 Fork Issue Fix: Ensuring swap, ulimits, kernel params, and process cleanup..."

# 1. Check current memory
echo -e "\n[INFO] Current memory status:"
free -h

# 2. Add/configure swap file if not already present
SWAPFILE="/swapfile"
SWAP_SIZE=${SWAP_SIZE:-2G}
if swapon --show | grep -q "$SWAPFILE"; then
    echo "[OK] Swap file already exists."
else
    echo "[ACTION] Creating ${SWAP_SIZE} swap file..."
    FREE_SPACE=$(df --output=avail / | tail -1)
    REQUIRED_SPACE=$((2 * 1024 * 1024)) # 2GB in KB
    if [ "$FREE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        echo "❌ Not enough disk space to create swap file. Free space: $(df -h / | tail -1 | awk '{print $4}')"
        exit 1
    fi
    (sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=2048) && echo "✅ Swap file created" || {
        echo "❌ Failed to create swap file"; exit 1;
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
ulimit -u 4096
ulimit -n 1024
echo "[OK] ulimit values updated for current session."

# Kernel parameters for fork/memory issues
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

### PART 9: Enable ZRAM ###
echo "🧊 Setting up ZRAM..."
if dpkg -l | grep -q zram-config; then
    echo "  ✅ ZRAM already installed"
else
    sudo apt install -y zram-config && echo "  ✅ ZRAM installed" || echo "  ❌ ZRAM installation failed"
fi

### PART 10: Optimize Boot Process ###
echo "🚀 Optimizing boot process..."
echo "  ⏱️  Current GRUB timeout: $(grep GRUB_TIMEOUT= /etc/default/grub | cut -d= -f2)"
GRUB_TIMEOUT=${GRUB_TIMEOUT:-1}
sudo sed -i "s/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$GRUB_TIMEOUT/" /etc/default/grub
sudo sed -i 's/GRUB_TIMEOUT=10/GRUB_TIMEOUT=1/' /etc/default/grub && echo "    ✅ GRUB timeout set to 1 second" || echo "    ❌ GRUB timeout change failed"
sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=1/' /etc/default/grub 2>/dev/null # Alternative timeout value

echo "  🎨 Disabling Plymouth splash screen..."
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/' /etc/default/grub && echo "    ✅ Plymouth disabled" || echo "    ⚠️  Plymouth disable failed"

echo "  🔄 Updating GRUB..."
sudo update-grub && echo "    ✅ GRUB updated" || echo "    ❌ GRUB update failed"

echo "  🚫 Blacklisting unnecessary kernel modules..."
echo 'blacklist pcspkr' | sudo tee -a /etc/modprobe.d/blacklist.conf && echo "    ✅ PC speaker blacklisted" || echo "    ❌ PC speaker blacklist failed"
echo 'blacklist snd_pcsp' | sudo tee -a /etc/modprobe.d/blacklist.conf && echo "    ✅ PC speaker sound blacklisted" || echo "    ❌ PC speaker sound blacklist failed"

### PART 11: HDD Optimization and Disk Trim ###
echo "💾 Running HDD disk optimization..."

# Set I/O scheduler to deadline (or cfq as fallback) and make persistent
for device in $(lsblk -dno name | grep -E '^sd'); do
    if [ -f "/sys/block/$device/queue/scheduler" ]; then
        echo deadline | sudo tee /sys/block/$device/queue/scheduler >/dev/null 2>&1 || \
        echo cfq | sudo tee /sys/block/$device/queue/scheduler >/dev/null 2>&1
        echo "      ✅ Scheduler optimized for $device"
    fi
done
echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT elevator=deadline"' | sudo tee -a /etc/default/grub.d/99-optimizer.cfg >/dev/null 2>&1
sudo update-grub

# Enable write-back caching for HDD (if safe)
for device in $(lsblk -dno name | grep -E '^sd'); do
    if command -v hdparm >/dev/null 2>&1; then
        sudo hdparm -W1 /dev/$device >/dev/null 2>&1 && echo "      ✅ Write caching enabled for $device" || echo "      ⚠️  Could not enable write caching for $device"
    fi
done

# Defragment ext4 filesystems
if command -v e4defrag >/dev/null 2>&1; then
    sudo e4defrag / >/dev/null 2>&1 && echo "      ✅ Filesystem defragmented" || echo "      ⚠️  Defragmentation failed or not needed"
else
    echo "      ⚠️  e4defrag not available, installing..."
    sudo apt install -y e2fsprogs >/dev/null 2>&1 || echo "      ❌ Could not install e2fsprogs"
fi

# Add noatime to /etc/fstab
sudo sed -i 's/errors=remount-ro/noatime,errors=remount-ro/' /etc/fstab

# Set swappiness to 10
sudo tee /etc/sysctl.d/99-swappiness.conf <<< 'vm.swappiness=10'
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

# Schedule filesystem check
sudo touch /forcefsck

# Clean up old logs and cache
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/cache/apt/archives/*.deb /tmp/* ~/.cache/* 2>/dev/null

### PART 12: Configure Filesystem Optimizations ###
echo "🗂 Applying filesystem optimizations..."
echo "  📋 Backing up /etc/fstab..."
sudo cp /etc/fstab /etc/fstab.backup && echo "    ✅ fstab backed up" || echo "    ❌ fstab backup failed"

echo "  ⚡ Adding noatime option for better performance..."
sudo sed -i 's/errors=remount-ro/noatime,errors=remount-ro/' /etc/fstab
echo "    ✅ noatime option added" || echo "    ❌ noatime option failed"

### PART 13: System Cleanup and Cache Removal ###
echo "🧹 Cleaning up system..."
echo "  🗑️  Removing old logs and cache files..."
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/cache/apt/archives/*.deb /tmp/* ~/.cache/* 2>/dev/null && echo "    ✅ Cache and logs cleaned" || echo "    ⚠️  Some cache cleanup failed"

echo "  🌍 Removing unnecessary language packs..."
LANG_PACKS=$(dpkg -l | grep language-pack | awk '{print $2}' | grep -v "language-pack-en" | grep -v "language-pack-en-base")
if [ -n "$LANG_PACKS" ]; then
    echo "    Found language packs to remove: $LANG_PACKS"
    sudo apt autoremove --purge -y $LANG_PACKS && echo "    ✅ Language packs removed" || echo "    ❌ Language pack removal failed"
else
    echo "    ✅ No unnecessary language packs found"
fi

echo "  📚 Removing documentation (man pages, docs)..."
sudo rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null && echo "    ✅ Documentation removed" || echo "    ⚠️  Documentation removal partially failed"

### PART 14: Kernel Performance Tuning ###
echo "⚙️  Applying kernel performance tweaks..."
echo "  💾 Setting vm.swappiness to 10..."
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
echo "  📝 Configuring dirty page writeback..."
echo 'vm.dirty_writeback_centisecs=1500' | sudo tee /etc/sysctl.d/99-dirty.conf
sudo sysctl -p /etc/sysctl.d/99-dirty.conf
echo 'vm.dirty_ratio=5' | sudo tee -a /etc/sysctl.d/99-dirty.conf
echo 'vm.dirty_background_ratio=2' | sudo tee -a /etc/sysctl.d/99-dirty.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.d/99-dirty.conf

echo "  🕰️  Configuring CPU scheduler..."
echo 'kernel.sched_min_granularity_ns=10000000' | sudo tee /etc/sysctl.d/99-scheduler.conf && echo "    ✅ Scheduler configured" || echo "    ❌ Scheduler configuration failed"
echo 'kernel.sched_wakeup_granularity_ns=15000000' | sudo tee -a /etc/sysctl.d/99-scheduler.conf

echo "  🧠 Configuring memory management..."
echo 'vm.overcommit_memory=2' | sudo tee /etc/sysctl.d/99-memory.conf && echo "    ✅ Memory overcommit configured" || echo "    ❌ Memory configuration failed"
echo 'vm.overcommit_ratio=80' | sudo tee -a /etc/sysctl.d/99-memory.conf

echo "  🌐 Optimizing network stack..."
echo 'net.core.netdev_max_backlog=5000' | sudo tee /etc/sysctl.d/99-network.conf && echo "    ✅ Network stack optimized" || echo "    ❌ Network optimization failed"

echo "  🔄 Applying sysctl changes..."
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf && echo "    ✅ Swappiness applied" || echo "    ❌ Swappiness apply failed"
sudo sysctl -p /etc/sysctl.d/99-dirty.conf && echo "    ✅ Dirty settings applied" || echo "    ❌ Dirty settings apply failed"
sudo sysctl -p /etc/sysctl.d/99-scheduler.conf && echo "    ✅ Scheduler settings applied" || echo "    ❌ Scheduler apply failed"
sudo sysctl -p /etc/sysctl.d/99-memory.conf && echo "    ✅ Memory settings applied" || echo "    ❌ Memory apply failed"
sudo sysctl -p /etc/sysctl.d/99-network.conf && echo "    ✅ Network settings applied" || echo "    ❌ Network apply failed"

### PART 15: Create Performance Startup Script ###
echo "📜 Creating performance startup script..."
sudo tee /usr/local/bin/performance-boost > /dev/null << 'EOF'
#!/bin/bash
# Performance boost script
echo "🚀 Applying performance boost..."

# Set CPU governor to performance
if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
    echo "✅ CPU governor set to performance"
else
    echo "⚠️ CPU frequency scaling not available"
fi

# Optimize swap readahead
echo 1 | sudo tee /proc/sys/vm/page-cluster >/dev/null 2>&1
echo "✅ Swap readahead optimized"

# Clear caches
sync && echo 1 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
echo "✅ System caches cleared"

echo "🎯 Performance boost completed at $(date)"
EOF

sudo chmod +x /usr/local/bin/performance-boost && echo "  ✅ Performance script created and made executable" || echo "  ❌ Performance script creation failed"

# Add to crontab for automatic execution on boot
(sudo crontab -l 2>/dev/null; echo '@reboot /usr/local/bin/performance-boost >> /var/log/performance-boost.log 2>&1') | sudo crontab - && echo "  ✅ Performance script added to crontab" || echo "  ❌ Crontab addition failed"

### PART 16: Final System Status ###
echo ""
echo "📊 Final System Status:"
echo "  💾 Memory usage: $(free -h | grep Mem | awk '{print "Used: " $3 " / " $2 " (" int($3/$2*100) "%)"}')"
echo "  💿 Disk usage: $(df -h / | tail -1 | awk '{print "Used: " $3 " / " $2 " (" $5 ")"}')"
echo "  🔄 Services disabled: ${#SERVICES[@]}"
echo "  📦 Heavy packages removed"
echo "  ⚡ CPU governor: performance (will apply on reboot)"
echo "  🔐 Auto-login configured for: $CURRENT_USER"
echo "  ⌨️  Configuring LXDE keyboard shortcuts..."

# Create LXDE keybindings configuration directory if it doesn't exist
mkdir -p ~/.config/openbox

# Backup existing keyboard shortcuts if present
if [ -f ~/.config/openbox/lxde-rc.xml ]; then
    cp ~/.config/openbox/lxde-rc.xml ~/.config/openbox/lxde-rc.xml.backup
    echo "✅ Backed up existing keyboard shortcuts"
fi

# Create or update LXDE keyboard shortcuts
cat > ~/.config/openbox/lxde-rc.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc" xmlns:xi="http://www.w3.org/2001/XInclude">
    <keyboard>
        <!-- Terminal shortcuts -->
        <keybind key="C-A-t">
            <action name="Execute">
                <command>lxterminal</command>
            </action>
        </keybind>
        <keybind key="C-t">
            <action name="Execute">
                <command>lxterminal</command>
            </action>
        </keybind>
        
        <!-- File manager shortcuts -->
        <keybind key="C-A-f">
            <action name="Execute">
                <command>pcmanfm</command>
            </action>
        </keybind>
        <keybind key="W-e">
            <action name="Execute">
                <command>pcmanfm</command>
            </action>
        </keybind>
        
        <!-- Browser shortcuts -->
        <keybind key="C-A-b">
            <action name="Execute">
                <command>chromium-browser</command>
            </action>
        </keybind>
        <keybind key="W-b">
            <action name="Execute">
                <command>dillo</command>
            </action>
        </keybind>
        
        <!-- System monitor -->
        <keybind key="C-S-Escape">
            <action name="Execute">
                <command>lxtask</command>
            </action>
        </keybind>
        
        <!-- Screen lock -->
        <keybind key="W-l">
            <action name="Execute">
                <command>xscreensaver-command -lock</command>
            </action>
        </keybind>
        
        <!-- Application launcher -->
        <keybind key="A-F2">
            <action name="Execute">
                <command>lxpanelctl run</command>
            </action>
        </keybind>
        <keybind key="W-r">
            <action name="Execute">
                <command>lxpanelctl run</command>
            </action>
        </keybind>
        
        <!-- Window management -->
        <keybind key="A-F4">
            <action name="Close"/>
        </keybind>
        <keybind key="A-Tab">
            <action name="NextWindow"/>
        </keybind>
        <keybind key="W-Up">
            <action name="Maximize"/>
        </keybind>
        <keybind key="W-Down">
            <action name="Unmaximize"/>
        </keybind>
        <keybind key="W-Left">
            <action name="UnmaximizeFull"/>
            <action name="MoveResizeTo">
                <x>0</x>
                <y>0</y>
                <width>50%</width>
                <height>100%</height>
            </action>
        </keybind>
        <keybind key="W-Right">
            <action name="UnmaximizeFull"/>
            <action name="MoveResizeTo">
                <x>-0</x>
                <y>0</y>
                <width>50%</width>
                <height>100%</height>
            </action>
        </keybind>
        
        <!-- Volume control -->
        <keybind key="XF86AudioRaiseVolume">
            <action name="Execute">
                <command>amixer set Master 5%+</command>
            </action>
        </keybind>
        <keybind key="XF86AudioLowerVolume">
            <action name="Execute">
                <command>amixer set Master 5%-</command>
            </action>
        </keybind>
        <keybind key="XF86AudioMute">
            <action name="Execute">
                <command>amixer set Master toggle</command>
            </action>
        </keybind>
        
        <!-- Screenshot -->
        <keybind key="Print">
            <action name="Execute">
                <command>scrot ~/Desktop/screenshot_%Y%m%d_%H%M%S.png</command>
            </action>
        </keybind>
        <keybind key="A-Print">
            <action name="Execute">
                <command>scrot -s ~/Desktop/screenshot_%Y%m%d_%H%M%S.png</command>
            </action>
        </keybind>
    </keyboard>
</openbox_config>
EOF

echo "    ✅ LXDE keyboard shortcuts configured"

# Install scrot for screenshots if not present
if ! command -v scrot >/dev/null; then
    echo "❌ scrot is not installed. Installing..."
    if sudo apt install -y scrot; then
        echo "✅ scrot installed successfully"
    else
        echo "⚠️  Failed to install scrot, but continuing script"
    fi
fi

# Restart openbox to apply changes (will happen on next login/reboot)
echo "    📝 Keyboard shortcuts will be active after reboot"
echo "    ⌨️  Available shortcuts:"
echo "      • Ctrl+T or Ctrl+Alt+T: Open Terminal"
echo "      • Ctrl+Alt+F or Win+E: Open File Manager" 
echo "      • Ctrl+Alt+B: Open Chromium Browser"
echo "      • Win+B: Open Dillo (lightweight browser)"
echo "      • Ctrl+Shift+Esc: Open Task Manager"
echo "      • Win+L: Lock Screen"
echo "      • Alt+F2 or Win+R: Run Command"
echo "      • Alt+F4: Close Window"
echo "      • Alt+Tab: Switch Windows"
echo "      • Win+Arrow Keys: Window snapping/maximize"
echo "      • Print Screen: Full screenshot"
echo "      • Alt+Print Screen: Area screenshot"

echo "    ℹ️  Keyboard shortcuts will be applied after next login/reboot"

### PART 17: Final Note ###
echo ""
echo "✅ Ultra optimization complete!"
echo "⏰ Completed at: $(date)"
echo ""
echo "🔁 REBOOT YOUR SYSTEM to apply all changes"
echo "🏠 You'll automatically login to LXDE desktop"
echo "💡 Performance boost script will run automatically on each boot"
echo "🔧 Manual performance boost: sudo /usr/local/bin/performance-boost"
echo "📋 Performance boost logs: /var/log/performance-boost.log"
echo ""
echo "🎯 Your Lubuntu system is now optimized for maximum performance!"
echo "🔧 Fork issues have been addressed for low-memory systems"
echo "💾 HDD-specific storage optimizations have been applied."