#!/bin/bash

# CONFIGURATION
USERNAME=$(whoami)
TTY="tty1"
GETTY_OVERRIDE="/etc/systemd/system/getty@${TTY}.service.d/override.conf"

echo "➡️ Installing LXDE and xinit..."
sudo apt update
sudo apt install -y lxde xinit

echo "✅ Installation complete."

echo "➡️ Creating ~/.xinitrc to start LXDE..."
echo "exec startlxde" > "$HOME/.xinitrc"
chmod +x "$HOME/.xinitrc"

echo "✅ .xinitrc created."

echo "➡️ Setting up systemd autologin for $USERNAME on $TTY..."
sudo mkdir -p "$(dirname "$GETTY_OVERRIDE")"

sudo bash -c "cat > $GETTY_OVERRIDE" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
EOF

echo "✅ Autologin systemd override written."

echo "➡️ Reloading systemd daemon..."
sudo systemctl daemon-reexec
sudo systemctl restart "getty@${TTY}"

echo "➡️ Configuring .bash_profile to start X on TTY1..."
BASH_PROFILE="$HOME/.bash_profile"
if ! grep -q "startx" "$BASH_PROFILE" 2>/dev/null; then
  echo -e '\nif [[ -z $DISPLAY && $(tty) == /dev/tty1 ]]; then\n  startx\nfi' >> "$BASH_PROFILE"
  echo "✅ .bash_profile updated."
else
  echo "⚠️ .bash_profile already contains a startx command. Skipping."
fi

echo "🎉 Done! Reboot to start LXDE automatically on TTY1 without LightDM."

