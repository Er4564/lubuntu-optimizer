#!/bin/bash
echo "🚀 Starting ULTRA optimization for Lubuntu..."

### PART 1: Remove Desktop Bloat and Unused Apps ###
echo "📦 Removing unused desktop applications..."
sudo apt purge -y \
  abiword gnumeric pidgin transmission-* thunderbird \
  xsane simple-scan gnome-mahjongg gnome-sudoku \
  onboard hexchat xpad gnome-mines \
  firefox chromium-browser libreoffice* \
  brasero cheese deja-dup \
  zeitgeist-core remmina \
  gnome-orca \
  update-manager update-notifier \
  apport apport-gtk \
  gufw

sudo apt autoremove -y
sudo apt clean

### PART 2: Disable Background Services ###
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
)

for svc in "${SERVICES[@]}"; do
  sudo systemctl disable "$svc" 2>/dev/null
  sudo systemctl stop "$svc" 2>/dev/null
done

### PART 3: Lightweight Replacements ###
echo "🛠 Installing lightweight alternatives..."
sudo apt install -y leafpad audacious pcmanfm lxterminal htop zram-config synaptic

### PART 4: Trim Disk (For SSD or Flash) ###
echo "💾 Running fstrim on root (for SSD or flash drives)..."
if [ -x /usr/sbin/fstrim ]; then
  sudo fstrim -v /
fi

### PART 5: Set up Swap if Missing ###
echo "🧠 Checking swap space..."
if free | awk '/^Swap:/ {exit !$2}'; then
  echo "✅ Swap already exists."
else
  echo "❗ Creating 1 GB swap file..."
  sudo fallocate -l 1G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

### PART 6: Enable & Configure ZRAM ###
echo "🧊 Setting up ZRAM..."
sudo apt install -y zram-config
echo "ZRAM enabled."

### PART 7: Disable Compositing (LXDE only) ###
echo "🎨 Disabling LXDE compositing..."
mkdir -p ~/.config/lxsession/Lubuntu
echo -e '[Session]\nwindow_manager=openbox\n' > ~/.config/lxsession/Lubuntu/desktop.conf

### PART 8: Clean Cache, Logs, Temp Files ###
echo "🧹 Cleaning logs and temp files..."
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/cache/apt/archives/*.deb /tmp/* ~/.cache/thumbnails/* ~/.cache/mozilla/*
sudo journalctl --vacuum-time=1d > /dev/null

### PART 9: Performance Tuning Parameters ###
echo "⚙️ Setting system performance tweaks..."

# Swappiness
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf

# Reduce write-back time (flush dirty cache sooner)
echo 'vm.dirty_writeback_centisecs=1500' | sudo tee -a /etc/sysctl.d/99-perf.conf

# Disable access time writes
echo 'noatime' | sudo tee -a /etc/fstab

sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-perf.conf

### PART 10: LXDE Autostart Tweak ###
echo "🧼 Trimming LXDE autostart..."
mkdir -p ~/.config/autostart
cat <<EOF > ~/.config/autostart/lxde-light.desktop
[Desktop Entry]
Type=Application
Exec=openbox
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Light LXDE
EOF

echo "✅ Optimization complete. Reboot recommended."
