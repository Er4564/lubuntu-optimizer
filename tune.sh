#!/bin/bash
echo "🚀 Starting FINAL ultra optimization for Lubuntu..."
echo "ℹ️  This script will keep LXDE and set up auto-login"
echo "⏰ Started at: $(date)"

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

for pkg in "${HEAVY_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii.*$pkg"; then
        echo "    🗑️  Removing $pkg..."
        sudo apt purge -y "$pkg" 2>/dev/null && echo "      ✅ Removed $pkg" || echo "      ⚠️  Failed to remove $pkg"
    else
        echo "    ⚠️  Package $pkg not installed"
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
)

for pkg in "${LIGHT_PACKAGES[@]}"; do
    echo "  📦 Installing $pkg..."
    if [ "$pkg" = "chromium-browser" ]; then
        sudo apt install -y "$pkg" --no-install-recommends && echo "    ✅ Installed $pkg" || echo "    ❌ Failed to install $pkg"
    else
        sudo apt install -y "$pkg" && echo "    ✅ Installed $pkg" || echo "    ❌ Failed to install $pkg"
    fi
done

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

# Set governor to performance
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils > /dev/null
echo "  📝 Set default governor to performance in /etc/default/cpufrequtils"

# Apply immediately
sudo cpufreq-set -g performance 2>/dev/null && echo "  ✅ CPU governor set to performance" || echo "  ⚠️  Unable to set governor immediately (will apply on reboot)"

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

### PART 7: Configure Lightweight Alternatives ###
echo "🔧 Setting up lightweight alternatives..."
echo "  🐚 Configuring dash as default shell..."
echo "dash dash/sh boolean true" | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash && echo "    ✅ Dash configured" || echo "    ⚠️  Dash configuration failed"

echo "  🌐 Setting lightweight default browser..."
sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/dillo 50 && echo "    ✅ Dillo set as default browser" || echo "    ⚠️  Browser alternative failed"

### PART 8: Enable Swap if Missing ###
echo "🧠 Checking swap configuration..."
if free | awk '/^Swap:/ {exit !$2}'; then
    echo "  ✅ Swap already exists: $(free -h | grep Swap | awk '{print $2}')"
else
    echo "  📝 Creating 1GB swap file..."
    sudo fallocate -l 1G /swapfile && echo "    ✅ Swap file allocated" || echo "    ❌ Swap file allocation failed"
    sudo chmod 600 /swapfile && echo "    ✅ Swap file permissions set" || echo "    ❌ Swap file permissions failed"
    sudo mkswap /swapfile && echo "    ✅ Swap file formatted" || echo "    ❌ Swap file format failed"
    sudo swapon /swapfile && echo "    ✅ Swap file activated" || echo "    ❌ Swap file activation failed"
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab && echo "    ✅ Swap file added to fstab" || echo "    ❌ Failed to add swap to fstab"
fi

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
sudo sed -i 's/GRUB_TIMEOUT=10/GRUB_TIMEOUT=1/' /etc/default/grub && echo "    ✅ GRUB timeout set to 1 second" || echo "    ❌ GRUB timeout change failed"
sudo sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=1/' /etc/default/grub 2>/dev/null # Alternative timeout value

echo "  🎨 Disabling Plymouth splash screen..."
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/' /etc/default/grub && echo "    ✅ Plymouth disabled" || echo "    ⚠️  Plymouth disable failed"

echo "  🔄 Updating GRUB..."
sudo update-grub && echo "    ✅ GRUB updated" || echo "    ❌ GRUB update failed"

echo "  🚫 Blacklisting unnecessary kernel modules..."
echo 'blacklist pcspkr' | sudo tee -a /etc/modprobe.d/blacklist.conf && echo "    ✅ PC speaker blacklisted" || echo "    ❌ PC speaker blacklist failed"
echo 'blacklist snd_pcsp' | sudo tee -a /etc/modprobe.d/blacklist.conf && echo "    ✅ PC speaker sound blacklisted" || echo "    ❌ PC speaker sound blacklist failed"

### PART 11: Trim Disk (For SSD or Flash) ###
echo "💾 Running disk trim..."
if [ -x /usr/sbin/fstrim ]; then
    sudo fstrim -v / && echo "  ✅ Disk trim completed" || echo "  ❌ Disk trim failed"
else
    echo "  ⚠️  fstrim not available"
fi

### PART 12: Configure Filesystem Optimizations ###
echo "🗂 Applying filesystem optimizations..."
echo "  📋 Backing up /etc/fstab..."
sudo cp /etc/fstab /etc/fstab.backup && echo "    ✅ fstab backed up" || echo "    ❌ fstab backup failed"

echo "  ⚡ Adding noatime option for better performance..."
sudo sed -i 's/errors=remount-ro/noatime,errors=remount-ro/' /etc/fstab && echo "    ✅ noatime option added" || echo "    ❌ noatime option failed"

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
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf && echo "    ✅ Swappiness configured" || echo "    ❌ Swappiness configuration failed"

echo "  📝 Configuring dirty page writeback..."
echo 'vm.dirty_writeback_centisecs=1500' | sudo tee /etc/sysctl.d/99-dirty.conf && echo "    ✅ Dirty writeback configured" || echo "    ❌ Dirty writeback failed"
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
