# Lubuntu Optimizer

## Description
Lubuntu Optimizer is a script designed to enhance the performance of Lubuntu, especially on low-resource systems such as those with Intel Atom processors and 1GB RAM. The script focuses on optimizing system settings, removing unnecessary packages, and configuring lightweight alternatives to ensure maximum efficiency.

## Features
- Removes heavy and unnecessary packages while keeping LXDE.
- Installs lightweight applications for better performance.
- Configures auto-login for LXDE.
- Sets CPU governor to performance mode.
- Installs and configures auto-cpufreq for advanced CPU frequency management.
- Enables ZRAM for memory compression.
- Optimizes boot process and reduces GRUB timeout.
- Disables unused services to free up system resources.
- Configures lightweight alternatives for browsers, file managers, and more.
- Creates a swap file and optimizes memory settings.
- Applies kernel performance tweaks.
- Cleans up system cache and unnecessary files.
- Includes fork issue fix script for low-memory systems.
- Configures system limits and process management optimizations.

## Installation Guide

### Option 1: Clone the Repository
1. Clone the repository:
   ```bash
   git clone https://github.com/Er4564/lubuntu-optimizer.git
   cd lubuntu-optimizer
   ```

2. Make the script executable:
   ```bash
   chmod +x Lubuntu\ Optimizer.sh
   ```

3. Run the script:
   ```bash
   sudo ./Lubuntu\ Optimizer.sh
   ```

4. Reboot your system to apply all changes:
   ```bash
   sudo reboot
   ```

### Option 2: Download with `wget`
1. Download the script directly using `wget`:
   ```bash
   wget -O Lubuntu-Optimizer.sh https://raw.githubusercontent.com/Er4564/lubuntu-optimizer/main/Lubuntu%20Optimizer.sh
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

### Option 3: Download with `curl`
1. Download the script directly using `curl`:
   ```bash
   curl -o Lubuntu-Optimizer.sh https://raw.githubusercontent.com/Er4564/lubuntu-optimizer/main/Lubuntu%20Optimizer.sh
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

## Additional Scripts

### Fork Issue Fix Script
For systems experiencing "failed to fork" errors due to low memory, use the fork issue fix script:

```bash
# Download the fork fix script
wget -O fix_fork_issue.sh https://raw.githubusercontent.com/Er4564/lubuntu-optimizer/main/fix_fork_issue.sh

# Make it executable
chmod +x fix_fork_issue.sh

# Run the script
sudo ./fix_fork_issue.sh
```

This script:
- Creates additional swap space (configurable via `SWAP_SIZE` environment variable)
- Optimizes kernel parameters for low-memory systems
- Increases system limits for processes and file descriptors
- Cleans up zombie processes and system cache
- Makes permanent changes to prevent future fork issues

## Notes
- Ensure you have root privileges to run the script.
- The script is designed for Lubuntu systems and may not work as intended on other distributions.
- After running the script, your system will be optimized for lightweight performance.

## License
This project is licensed under the MIT License.
