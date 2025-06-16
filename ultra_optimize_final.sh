#!/bin/bash
echo "🚀 Starting FINAL ultra optimization for Lubuntu..."

### PART 1: Remove Heavy Desktop Environment ###
echo "❌ Removing LXDE and related packages..."
sudo apt purge -y lxde* lxsession* lightdm* xscreensaver* gvfs* gnome* xdg-user-dirs*
# Add more packages to remove
sudo apt purge -y ubuntu-desktop-minimal snapd network-manager-gnome pulseaudio* apport* popularity-contest
sudo apt autoremove -y
sudo apt clean

### PART 2: Install Minimal Openbox Environment ###
echo "🧱 Installing Openbox + minimal GUI..."
sudo apt install -y openbox obconf tint2 lxappearance xinit xorg leafpad pcmanfm lxterminal

# Set up .xinitrc for Openbox
echo "🏁 Configuring startx with Openbox..."
echo 'exec openbox-session' > ~/.xinitrc

### PART 3: Boot to TTY (No graphical login manager) ###
echo "🖥 Setting system to boot into TTY..."
sudo systemctl set-default multi-user.target

### PART 4: Install TLP (power-saving) ###
echo "🔋 Installing TLP for power management..."
sudo apt install -y tlp tlp-rdw
sudo systemctl enable tlp
sudo systemctl start tlp

### PART 5: Disable Unused Services ###
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
  sudo systemctl disable "$svc" 2>/dev/null
  sudo systemctl stop "$svc" 2>/dev/null
done
### PART 5.1: Remove Snap Packages ###
echo "📦 Removing Snap packages...
sudo snap remove --purge firefox 2>/dev/null || true
sudo snap remove --purge snap-store 2>/dev/null || true
sudo snap remove --purge core* 2>/dev/null || true
sudo apt purge -y snapd
sudo rm -rf /var/snap /snap /var/lib/snapd"
### PART 5.5: Remove Snap Completely ###
echo "📦 Removing Snap packages..."
sudo snap remove --purge firefox 2>/dev/null || true
sudo snap remove --purge snap-store 2>/dev/null || true
sudo snap remove --purge core* 2>/dev/null || true
sudo apt purge -y snapd
sudo rm -rf /var/snap /snap /var/lib/snapd
### PART 6: Install Lightweight Apps ###
echo "📦 Installing lightweight tools..."
sudo apt install -y audacious htop zram-config dillo surf links2
# Replace Firefox with lightweight browsers
sudo apt install -y chromium-browser --no-install-recommends

### PART 6.5: Configure Lightweight Alternatives ###
echo "🔧 Setting up lightweight alternatives..."
# Use dash instead of bash for faster boot
sudo dpkg-reconfigure dash
# Set lightweight default applications
sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/dillo 50


### PART 7: Enable Swap if Missing ###
echo "🧠 Setting up swap file..."
if free | awk '/^Swap:/ {exit !$2}'; then
  echo "✅ Swap already exists."
else
  sudo fallocate -l 1G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

### PART 8: Enable ZRAM ###
echo "🧊 Setting up ZRAM..."
sudo apt install -y zram-config

### PART 8.5: Optimize Boot Process ###
echo "🚀 Optimizing boot process..."
# Reduce GRUB timeout
sudo sed -i 's/GRUB_TIMEOUT=10/GRUB_TIMEOUT=1/' /etc/default/grub
sudo update-grub
# Disable Plymouth splash screen
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/' /etc/default/grub
sudo update-grub
# Remove unnecessary kernel modules
echo 'blacklist pcspkr' | sudo tee -a /etc/modprobe.d/blacklist.conf
echo 'blacklist snd_pcsp' | sudo tee -a /etc/modprobe.d/blacklist.conf


### PART 9: Trim Disk (For SSD or Flash) ###
echo "💾 Running fstrim..."
if [ -x /usr/sbin/fstrim ]; then
  sudo fstrim -v /
fi

### PART 9.5: Configure Filesystem Optimizations ###
echo "🗂 Applying filesystem optimizations..."
# Add noatime to fstab for better performance
sudo cp /etc/fstab /etc/fstab.backup
sudo sed -i 's/errors=remount-ro/noatime,errors=remount-ro/' /etc/fstab


### PART 10: System Cleanup and Cache Removal ###
echo "🧹 Cleaning up logs, cache, and temp files..."
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/cache/apt/archives/*.deb /tmp/* ~/.cache/*
# Remove language packs
sudo apt autoremove --purge -y `dpkg -l | grep language-pack | awk '{print $2}' | grep -v "language-pack-en"`
# Remove documentation
sudo rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/*

### PART 11: Kernel Performance Tuning ###
echo "⚙️ Applying system performance tweaks..."
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
echo 'vm.dirty_writeback_centisecs=1500' | sudo tee /etc/sysctl.d/99-dirty.conf
# Additional performance tweaks
echo 'vm.dirty_ratio=5' | sudo tee -a /etc/sysctl.d/99-dirty.conf
echo 'vm.dirty_background_ratio=2' | sudo tee -a /etc/sysctl.d/99-dirty.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.d/99-dirty.conf
echo 'kernel.sched_min_granularity_ns=10000000' | sudo tee /etc/sysctl.d/99-scheduler.conf
echo 'kernel.sched_wakeup_granularity_ns=15000000' | sudo tee -a /etc/sysctl.d/99-scheduler.conf
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-dirty.conf
sudo sysctl -p /etc/sysctl.d/99-scheduler.conf

### PART 11.5: Memory and CPU Optimizations ###
echo "🧠 Applying memory and CPU optimizations..."
# Disable memory overcommit for stability
echo 'vm.overcommit_memory=2' | sudo tee /etc/sysctl.d/99-memory.conf
echo 'vm.overcommit_ratio=80' | sudo tee -a /etc/sysctl.d/99-memory.conf
# Optimize network stack
echo 'net.core.netdev_max_backlog=5000' | sudo tee /etc/sysctl.d/99-network.conf
sudo sysctl -p /etc/sysctl.d/99-memory.conf
sudo sysctl -p /etc/sysctl.d/99-network.conf

### PART 12: Create Performance Startup Script ###
echo "📜 Creating performance startup script..."
sudo tee /usr/local/bin/performance-boost << 'EOF'
#!/bin/bash
# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
# Disable swap readahead
echo 1 | sudo tee /proc/sys/vm/page-cluster 2>/dev/null
# Clear caches
sync && echo 1 | sudo tee /proc/sys/vm/drop_caches
EOF

sudo chmod +x /usr/local/bin/performance-boost
echo '@reboot root /usr/local/bin/performance-boost' | sudo tee -a /etc/crontab

### PART 13: Final Note ###
echo "✅ Ultra optimization complete."
echo "🔁 Reboot your system. You'll boot to a terminal (TTY)."
echo "👉 Login, then type 'startx' to launch Openbox."
echo "💡 For even better performance, run 'sudo /usr/local/bin/performance-boost' after boot."
