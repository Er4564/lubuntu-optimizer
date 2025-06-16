#!/bin/bash
echo "🚀 Starting FINAL ultra optimization for Lubuntu..."

### PART 1: Remove Heavy Desktop Environment ###
echo "❌ Removing LXDE and related packages..."
sudo apt purge -y lxde* lxsession* lightdm* xscreensaver* gvfs* gnome* xdg-user-dirs*
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
)

for svc in "${SERVICES[@]}"; do
  sudo systemctl disable "$svc" 2>/dev/null
  sudo systemctl stop "$svc" 2>/dev/null
done

### PART 6: Install Lightweight Apps ###
echo "📦 Installing lightweight tools..."
sudo apt install -y audacious htop zram-config

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

### PART 9: Trim Disk (For SSD or Flash) ###
echo "💾 Running fstrim..."
if [ -x /usr/sbin/fstrim ]; then
  sudo fstrim -v /
fi

### PART 10: System Cleanup and Cache Removal ###
echo "🧹 Cleaning up logs, cache, and temp files..."
sudo rm -rf /var/log/*.gz /var/log/*.1 /var/cache/apt/archives/*.deb /tmp/* ~/.cache/*

### PART 11: Kernel Performance Tuning ###
echo "⚙️ Applying system performance tweaks..."
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
echo 'vm.dirty_writeback_centisecs=1500' | sudo tee /etc/sysctl.d/99-dirty.conf
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf
sudo sysctl -p /etc/sysctl.d/99-dirty.conf

### PART 12: Final Note ###
echo "✅ Optimization complete."
echo "🔁 Reboot your system. You'll boot to a terminal (TTY)."
echo "👉 Login, then type 'startx' to launch Openbox."

