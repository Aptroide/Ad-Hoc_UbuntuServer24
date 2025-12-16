#!/bin/bash

# Script to automate Ad-Hoc network configuration on Ubuntu Server 24
# Author: Ad-Hoc Configuration
# Date: 2025

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# Function to print messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Verify script is running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Banner
echo "================================================"
echo "  Ad-Hoc Network Setup - Ubuntu Server  "
echo "================================================"
echo ""

# Request network interface
echo -n "Enter the network interface name (e.g., wlan0): "
read INTERFACE

# Validate that the interface exists
if ! ip link show "$INTERFACE" &> /dev/null; then
    print_error "Interface $INTERFACE does not exist"
    echo "Available interfaces:"
    ip link show | grep -E "^[0-9]+" | awk '{print $2}' | sed 's/://'
    exit 1
fi

print_info "Selected interface: $INTERFACE"

# Request IP for Ad-Hoc network
echo -n "Enter the IP address for Ad-Hoc network (e.g., 192.168.1.20): "
read IP_ADDRESS

# Validate IP format (basic validation)
if ! [[ $IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    print_error "Invalid IP format"
    exit 1
fi

print_info "Assigned IP: $IP_ADDRESS/24"

# Request Ad-Hoc network name
echo -n "Enter the Ad-Hoc network name (e.g., MyAdHocNet): "
read ADHOC_SSID

# Request channel (frequency)
echo -n "Enter frequency in MHz (e.g., 2437 for channel 6, 2412 for channel 1): "
read FREQUENCY

print_info "Ad-Hoc network: $ADHOC_SSID on frequency $FREQUENCY MHz"

echo ""
echo "Configuration summary:"
echo "  - Interface: $INTERFACE"
echo "  - IP: $IP_ADDRESS/24"
echo "  - Ad-Hoc Network: $ADHOC_SSID"
echo "  - Frequency: $FREQUENCY MHz"
echo ""
echo -n "Do you want to continue? (y/n): "
read CONFIRM

if [[ ! $CONFIRM =~ ^[yY]$ ]]; then
    print_warning "Operation cancelled by user"
    exit 0
fi

echo ""
print_info "Starting configuration..."

# 1. Install dependencies
print_info "Step 1: Installing dependencies..."
apt update
apt install -y iw wpasupplicant iwd

# 2. Detect netplan file
print_info "Step 2: Detecting Netplan configuration file..."
NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -n 1)

if [ -z "$NETPLAN_FILE" ]; then
    print_warning "No Netplan configuration file found"
    print_info "Creating basic configuration file..."
    NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
    cat > "$NETPLAN_FILE" << EOF
network:
  version: 2
  ethernets:
    eth0:
      optional: true
      dhcp4: true
EOF
else
    print_info "Netplan file found: $NETPLAN_FILE"
    # Create backup
    cp "$NETPLAN_FILE" "${NETPLAN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    print_info "Backup created: ${NETPLAN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 3. Create Ad-Hoc configuration script
print_info "Step 3: Creating Ad-Hoc configuration script..."
cat > /usr/local/bin/wifi-adhoc.sh << EOF
#!/bin/bash
# Auto-generated script to configure Ad-Hoc mode
# Interface: $INTERFACE
# IP: $IP_ADDRESS/24
# Ad-Hoc Network: $ADHOC_SSID

ip link set $INTERFACE down
sleep 2

iw dev $INTERFACE set type ibss
sleep 2

ip link set $INTERFACE up
sleep 2

iw dev $INTERFACE ibss join $ADHOC_SSID $FREQUENCY
sleep 2

ip addr flush dev $INTERFACE
ip addr add $IP_ADDRESS/24 dev $INTERFACE
sleep 2

echo "Ad-Hoc network configured successfully"
EOF

chmod +x /usr/local/bin/wifi-adhoc.sh
print_info "Script created at /usr/local/bin/wifi-adhoc.sh"

# 4. Create systemd service
print_info "Step 4: Creating systemd service..."
cat > /etc/systemd/system/wifi-adhoc.service << EOF
[Unit]
Description=Configure WiFi in Ad-Hoc mode ($INTERFACE)
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-adhoc.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

print_info "Systemd service created"

# 5. Configure static IP in systemd-networkd
print_info "Step 5: Configuring static IP..."
cat > /etc/systemd/network/10-wifi-adhoc.network << EOF
[Match]
Name=$INTERFACE

[Network]
Address=$IP_ADDRESS/24
Gateway=192.168.1.1
DNS=8.8.8.8
DHCP=no
LinkLocalAddressing=no
IPv6AcceptRA=no
MulticastDNS=yes
EOF

print_info "Static network configuration created"

# 6. Disable conflicting configuration
print_info "Step 6: Disabling conflicting configurations..."
if [ -f "/usr/lib/systemd/network/80-wifi-adhoc.network" ]; then
    mv /usr/lib/systemd/network/80-wifi-adhoc.network /usr/lib/systemd/network/80-wifi-adhoc.network.bak
    print_info "Conflicting configuration disabled"
fi

# 7. Enable and start services
print_info "Step 7: Enabling services..."
systemctl daemon-reload
systemctl enable wifi-adhoc.service
systemctl restart systemd-networkd

print_info "Services enabled"

# 8. Create verification script
print_info "Step 8: Creating verification script..."
cat > /usr/local/bin/verify-adhoc.sh << EOF
#!/bin/bash
echo "=== Interface information for $INTERFACE ==="
echo ""
echo "Interface status:"
iw dev $INTERFACE info
echo ""
echo "IP address:"
ip addr show $INTERFACE
echo ""
echo "Network status:"
networkctl status $INTERFACE
EOF

chmod +x /usr/local/bin/verify-adhoc.sh
print_info "Verification script created at /usr/local/bin/verify-adhoc.sh"

echo -n "Do you want to reboot now? (y/n): "
read REBOOT_NOW

if [[ $REBOOT_NOW =~ ^[yY]$ ]]; then
    print_info "Rebooting system..."
    sleep 2
    reboot
else
    print_warning "Remember to reboot the system manually with: sudo reboot"
fi
