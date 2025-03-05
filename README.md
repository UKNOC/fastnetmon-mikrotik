# FastNetMon MikroTik Integration

A comprehensive integration script for using FastNetMon with MikroTik routers to automate DDoS mitigation via blackhole routing. The script provides real-time notifications through Discord and email when attacks are detected and mitigated.

## Features

- **Automated Blackhole Routing**: Adds and removes blackhole routes on MikroTik routers in response to FastNetMon alerts
- **BGP Community Support**: Automatically sets BGP communities for blackholed routes to facilitate network-wide DDoS mitigation
- **Discord Notifications**: Real-time alerts with detailed attack information in your Discord channels
- **Email Notifications**: Professionally formatted HTML emails with attack details
- **Detailed Logging**: Comprehensive logging of all actions and results
- **Self-Diagnostics**: Built-in tools to verify dependencies and test notification systems
- **Robust Error Handling**: Graceful handling of missing dependencies and connectivity issues

## Requirements

- FastNetMon (Community or Advanced)
- MikroTik router(s) with SSH access enabled
- Linux server with bash shell
- Required packages:
  - `sshpass` - For non-interactive SSH authentication
  - `curl` - For Discord notifications
  - `msmtp` (recommended), `sendmail`, or `mailutils` - For email notifications

## Installation

1. Download the script to your FastNetMon server:

```bash
wget -O /opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh https://raw.githubusercontent.com/UKNOC/fastnetmon-mikrotik/main/fastnetmon_mikrotik.sh
```

2. Make the script executable:

```bash
chmod +x /opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh
```

3. Edit the script to configure your MikroTik and notification settings:

```bash
nano /opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh
```

4. Update the FastNetMon configuration to use the script:

```bash
nano /etc/fastnetmon.conf
```

Add/modify these lines:

```
# Announce blocked IPs to MikroTik router
notify_script_path = /opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh
```

5. Verify your installation:

```bash
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh --check-packages
/opt/fastnetmon/scripts-community/fastnetmon_mikrotik.sh --check-notifications
```

## Configuration

### MikroTik Router Settings

```bash
# Configuration
ROUTER_IP="10.0.20.1"        # IP address of your MikroTik router
ROUTER_USER="api"            # SSH username
ROUTER_PASSWORD="password"   # SSH password
SSH_PORT=22                # SSH port (usually 22)
LOG_FILE="/tmp/fastnetmon_mikrotik.log"  # Log file path
```

### Discord Notifications

```bash
# Discord Webhook Configuration
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/your-webhook-url"
DISCORD_USERNAME="FastNetMon Alert"  # The name that will appear for the bot
DISCORD_AVATAR_URL=""  # Optional: URL to an avatar image
```

To set up Discord notifications:
1. Create a webhook in your Discord server (Server Settings → Integrations → Webhooks)
2. Copy the webhook URL into the configuration

### Email Notifications

```bash
# Email Configuration
SMTP_SERVER="smtp.gmail.com"  # Example: smtp.gmail.com for Gmail
SMTP_PORT="587"               # Common ports: 587 (STARTTLS), 465 (SSL)
SMTP_USER="your-email@gmail.com"  # Your full email address
SMTP_PASSWORD="your-app-password"  # For Gmail, use App Password
EMAIL_FROM="FastNetMon <your-email@gmail.com>"
EMAIL_TO="alerts@example.com, admin@example.com"  # Comma-separated list of recipients
EMAIL_SUBJECT_PREFIX="[ALERT] FastNetMon: "
EMAIL_NOTIFICATIONS_ENABLED="yes"  # Set to "no" to disable email notifications
```

For Gmail, you need to:
1. Enable 2-Step Verification for your Google account
2. Go to Security → App Passwords and generate a password
3. Use that 16-character password as SMTP_PASSWORD

## Usage

The script is designed to be called by FastNetMon automatically when it detects an attack, but you can also use it manually:

```bash
# Normal operation (usually called by FastNetMon)
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh <IP> <direction> <pps> <action>

# Examples:
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh 192.0.2.1 incoming 100000 ban
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh 192.0.2.1 incoming 0 unban

# Check if all required packages are installed
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh --check-packages

# Test notification systems
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh --check-notifications

# Display help
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh --help
```

## How It Works

1. When FastNetMon detects an attack, it calls the script with details about the attack
2. The script connects to the MikroTik router via SSH
3. It adds a blackhole route for the attacking IP address
4. It sets the appropriate BGP communities on the route
5. It sends notifications to Discord and/or email
6. When the attack subsides, FastNetMon calls the script again to remove the blackhole

## Troubleshooting

### Common Issues:

1. **SSH Connection Failures**:
   - Verify that SSH is enabled on your MikroTik router
   - Check that the IP, username, password, and port are correct
   - Ensure `sshpass` is installed

2. **Discord Notification Failures**:
   - Verify that `curl` is installed
   - Check that your webhook URL is correct
   - Ensure your server has internet access

3. **Email Notification Failures**:
   - Install `msmtp` for best results with external SMTP servers
   - Verify your SMTP settings (server, port, username, password)
   - If using Gmail, ensure you're using an App Password

Run the diagnostic tools to help troubleshoot:
```bash
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh --check-packages
/opt/fastnetmon-community/scripts/fastnetmon_mikrotik.sh --check-notifications
```


## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
