# Lubuntu Optimizer

## Description
Lubuntu Optimizer is a script designed to enhance the performance of Lubuntu, especially on low-resource systems such as those with Intel Atom processors and 1GB RAM. The script focuses on optimizing system settings, removing unnecessary packages, and configuring lightweight alternatives to ensure maximum efficiency.

## Features
- Removes heavy and unnecessary packages while keeping LXDE.
- Installs lightweight applications for better performance.
- Configures auto-login for LXDE.
- Sets CPU governor to performance mode.
- Enables ZRAM for memory compression.
- Optimizes boot process and reduces GRUB timeout.
- Disables unused services to free up system resources.
- Configures lightweight alternatives for browsers, file managers, and more.
- Creates a swap file and optimizes memory settings.
- Applies kernel performance tweaks.
- Cleans up system cache and unnecessary files.

## Installation Guide
1. Download the script:
   ```bash
   wget -O Lubuntu-Optimizer.sh https://example.com/path/to/Lubuntu%20Optimizer.sh
   ```

2. Make the script executable:
   ```bash
   chmod +x Lubuntu-Optimizer.sh
   ```

3. Run the script:
   ```bash
   sudo ./Lubuntu-Optimizer.sh
   ```

4. Reboot your system to apply all changes:
   ```bash
   sudo reboot
   ```

## Notes
- Ensure you have root privileges to run the script.
- The script is designed for Lubuntu systems and may not work as intended on other distributions.
- After running the script, your system will be optimized for lightweight performance.

## License
This project is licensed under the MIT License.
