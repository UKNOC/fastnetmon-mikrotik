#!/bin/bash
# FastNetMon MikroTik Integration using SSH - With Discord and Email Alerts
# This script connects to a MikroTik router via SSH to add or remove blackhole routes
# for IP addresses flagged by FastNetMon and sends notifications

# Configuration
ROUTER_IP="10.0.20.1"
ROUTER_USER="api"
ROUTER_PASSWORD="password"  # Update with your actual password
SSH_PORT=22
LOG_FILE="/tmp/fastnetmon_mikrotik.log"

# Discord Webhook Configuration
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL_HERE"  # Update with your Discord webhook URL
DISCORD_USERNAME="FastNetMon Alert"  # The name that will appear for the bot
DISCORD_AVATAR_URL=""  # Optional: URL to an avatar image

# Email Configuration
SMTP_SERVER="smtp.gmail.com"  # Example: smtp.gmail.com for Gmail
SMTP_PORT="587"              # Common ports: 587 (STARTTLS), 465 (SSL)
SMTP_USER="your-email@gmail.com"  # Your full email address
SMTP_PASSWORD="your-app-password"  # For Gmail, use App Password
EMAIL_FROM="FastNetMon <your-email@gmail.com>"
EMAIL_TO="alerts@example.com, admin@example.com"  # Comma-separated list of recipients
EMAIL_SUBJECT_PREFIX="[ALERT] FastNetMon: "
EMAIL_NOTIFICATIONS_ENABLED="yes"  # Set to "no" to disable email notifications

# TIP: For Gmail, you need to create an App Password:
# 1. Enable 2-Step Verification for your Google account
# 2. Go to Security > App Passwords and generate a password for this script
# 3. Use that 16-character password as SMTP_PASSWORD

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [FASTNETMON] - $1" >> "$LOG_FILE"
    echo "$1" >&2  # Output to stderr for FastNetMon
}

# Function to execute a single command via SSH
execute_ssh_command() {
    local command="$1"
    log_message "Executing command: $command"
    
    if command -v sshpass &> /dev/null; then
        result=$(sshpass -p "$ROUTER_PASSWORD" ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no "$ROUTER_USER@$ROUTER_IP" "$command" 2>&1)
        return_code=$?
        log_message "Result: $result (return code: $return_code)"
        return $return_code
    else
        log_message "ERROR: sshpass is not installed. Cannot execute SSH command."
        log_message "Please install sshpass: apt-get install sshpass"
        exit 1
    fi
}

# Function to send Discord notification
send_discord_alert() {
    # Check if curl is installed first
    if ! command -v curl &> /dev/null; then
        log_message "ERROR: curl is not installed. Cannot send Discord notifications."
        log_message "Please install curl: apt-get install curl"
        return 1
    fi

    local action="$1"
    local ip="$2"
    local direction="$3"
    local power="$4"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local color
    local title
    
    # Set color and title based on action (red for ban, green for unban, blue for test)
    if [ "$action" = "ban" ]; then
        color="16711680"  # Red in decimal
        title="🚫 IP Address Blocked"
    elif [ "$action" = "unban" ]; then
        color="65280"     # Green in decimal
        title="✅ IP Address Unblocked"
    elif [ "$action" = "test" ]; then
        color="3447003"   # Blue in decimal
        title="🔔 Test Notification"
    else
        color="16777215"  # White in decimal
        title="⚠️ FastNetMon Alert"
    fi
    
    # Create the JSON payload
    local payload='{
        "username": "'"$DISCORD_USERNAME"'",
        "avatar_url": "'"$DISCORD_AVATAR_URL"'",
        "embeds": [
            {
                "title": "'"$title"'",
                "color": '"$color"',
                "fields": [
                    {
                        "name": "IP Address",
                        "value": "'"$ip"'",
                        "inline": true
                    },
                    {
                        "name": "Action",
                        "value": "'"$action"'",
                        "inline": true
                    },
                    {
                        "name": "Router",
                        "value": "'"$ROUTER_IP"'",
                        "inline": true
                    },
                    {
                        "name": "Attack Direction",
                        "value": "'"$direction"'",
                        "inline": true
                    },
                    {
                        "name": "Attack Power",
                        "value": "'"$power"' pps",
                        "inline": true
                    }
                ],
                "footer": {
                    "text": "FastNetMon MikroTik Integration • '"$timestamp"'"
                }
            }
        ]
    }'
    
    # Send the notification
    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
        log_message "Sending Discord notification for $action of IP $ip"
        curl -s -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK_URL"
        if [ $? -eq 0 ]; then
            log_message "Discord notification sent successfully"
            return 0
        else
            log_message "ERROR: Failed to send Discord notification"
            return 1
        fi
    else
        log_message "WARNING: Discord webhook URL not configured, skipping notification"
        return 1
    fi
}

# Function to send HTML email notification
send_email_alert() {
    # Check if necessary tools are installed
    if ! command -v sendmail &> /dev/null && ! command -v mail &> /dev/null && ! command -v msmtp &> /dev/null; then
        log_message "ERROR: No mail sending utility found. Cannot send email notifications."
        log_message "Please install a mail utility: apt-get install mailutils or msmtp"
        return 1
    fi

    local action="$1"
    local ip="$2"
    local direction="$3"
    local power="$4"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local subject
    local bg_color
    local icon
    
    # Set email properties based on action
    if [ "$action" = "ban" ]; then
        subject="${EMAIL_SUBJECT_PREFIX}IP $ip BLOCKED - $POWER PPS"
        bg_color="#FF4136"  # Red background for ban actions
        icon="❌"
    elif [ "$action" = "unban" ]; then
        subject="${EMAIL_SUBJECT_PREFIX}IP $ip UNBLOCKED"
        bg_color="#2ECC40"  # Green background for unban actions
        icon="✅"
    elif [ "$action" = "test" ]; then
        subject="${EMAIL_SUBJECT_PREFIX}TEST NOTIFICATION"
        bg_color="#0074D9"  # Blue background for test notification
        icon="🔔"
    else
        subject="${EMAIL_SUBJECT_PREFIX}ALERT"
        bg_color="#AAAAAA"  # Gray background for unknown actions
        icon="⚠️"
    fi
    
    # Create a temporary file for the email content
    local email_file=$(mktemp)
    
    # Start creating HTML email content
    cat > "$email_file" << EOF
Content-Type: text/html; charset="UTF-8"
From: $EMAIL_FROM
To: $EMAIL_TO
Subject: $subject
MIME-Version: 1.0

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$subject</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: $bg_color;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px 5px 0 0;
        }
        .content {
            background-color: #f9f9f9;
            padding: 20px;
            border-left: 1px solid #ddd;
            border-right: 1px solid #ddd;
        }
        .footer {
            background-color: #f1f1f1;
            padding: 15px;
            text-align: center;
            font-size: 12px;
            color: #777;
            border-radius: 0 0 5px 5px;
            border: 1px solid #ddd;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        .alert-icon {
            font-size: 48px;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="alert-icon">$icon</div>
            <h1>FastNetMon Alert</h1>
EOF

    # Add specific title based on action
    if [ "$action" = "test" ]; then
        cat >> "$email_file" << EOF
            <h2>Test Notification</h2>
EOF
    else
        cat >> "$email_file" << EOF
            <h2>IP Address $action</h2>
EOF
    fi

    cat >> "$email_file" << EOF
        </div>
        <div class="content">
EOF

    # Add specific message for test notification
    if [ "$action" = "test" ]; then
        cat >> "$email_file" << EOF
            <p>This is a <strong>TEST</strong> notification from the FastNetMon DDoS protection system.</p>
            <p>If you're receiving this email, your email notification system is configured correctly!</p>
EOF
    else
        cat >> "$email_file" << EOF
            <p>This is an automated notification from the FastNetMon DDoS protection system.</p>
EOF
    fi

    cat >> "$email_file" << EOF
            <table>
                <tr>
                    <th>Property</th>
                    <th>Value</th>
                </tr>
                <tr>
                    <td><strong>IP Address</strong></td>
                    <td>$ip</td>
                </tr>
                <tr>
                    <td><strong>Action</strong></td>
                    <td>$action</td>
                </tr>
                <tr>
                    <td><strong>Router</strong></td>
                    <td>$ROUTER_IP</td>
                </tr>
                <tr>
                    <td><strong>Attack Direction</strong></td>
                    <td>$direction</td>
                </tr>
                <tr>
                    <td><strong>Attack Power</strong></td>
                    <td>$power pps</td>
                </tr>
                <tr>
                    <td><strong>Timestamp</strong></td>
                    <td>$timestamp</td>
                </tr>
            </table>
            
EOF

    if [ "$action" != "test" ]; then
        cat >> "$email_file" << EOF
            <p>Please investigate this activity and take appropriate action if needed.</p>
EOF
    fi

    cat >> "$email_file" << EOF
        </div>
        <div class="footer">
            <p>This is an automated message, please do not reply to this email.</p>
            <p>FastNetMon MikroTik Integration • Generated at $timestamp</p>
        </div>
    </div>
</body>
</html>
EOF

    # Try using msmtp first (specialized for sending to external SMTP servers)
    if command -v msmtp &> /dev/null; then
        log_message "Sending email notification for $action of IP $ip using msmtp"
        
        # Check if msmtp config exists, if not create a temporary one
        if [ ! -f ~/.msmtprc ]; then
            # Create temporary msmtp config
            local msmtp_config=$(mktemp)
            cat > "$msmtp_config" << MSMTPCONF
# MSMTP Configuration for FastNetMon
account default
host $SMTP_SERVER
port $SMTP_PORT
from $EMAIL_FROM
auth on
user $SMTP_USER
password $SMTP_PASSWORD
tls on
tls_starttls on
tls_certcheck off
MSMTPCONF
            
            log_message "Created temporary msmtp configuration"
            
            # Use the temporary config
            msmtp --file="$msmtp_config" -t < "$email_file"
            msmtp_result=$?
            
            # Clean up
            rm -f "$msmtp_config"
        else
            # Use existing config
            msmtp -t < "$email_file"
            msmtp_result=$?
        fi
        
        if [ $msmtp_result -eq 0 ]; then
            log_message "Email notification sent successfully using msmtp"
            email_result=0
        else
            log_message "ERROR: Failed to send email notification using msmtp (status: $msmtp_result)"
            email_result=1
        fi
    # Try using sendmail if available
    elif command -v sendmail &> /dev/null; then
        log_message "Sending email notification for $action of IP $ip using sendmail"
        sendmail -t < "$email_file"
        if [ $? -eq 0 ]; then
            log_message "Email notification sent successfully using sendmail"
            email_result=0
        else
            log_message "ERROR: Failed to send email notification using sendmail. Your server may not be configured for remote mail delivery."
            log_message "Try installing and configuring msmtp: apt-get install msmtp"
            email_result=1
        fi
    # Last try using mail command
    elif command -v mail &> /dev/null; then
        log_message "Sending email notification for $action of IP $ip using mail command"
        cat "$email_file" | mail -a "Content-Type: text/html" -s "$subject" "$EMAIL_TO"
        if [ $? -eq 0 ]; then
            log_message "Email notification sent successfully using mail command"
            email_result=0
        else
            log_message "ERROR: Failed to send email notification using mail command. Your server may not be configured for remote mail delivery."
            log_message "Try installing and configuring msmtp: apt-get install msmtp"
            email_result=1
        fi
    fi
    
    # Cleanup
    rm -f "$email_file"
    return $email_result
}

# Start with a clean log
echo "$(date '+%Y-%m-%d %H:%M:%S') - [FASTNETMON] - Script started" > "$LOG_FILE"

# Function to check required packages
check_packages() {
    log_message "Checking required packages..."
    local missing_packages=0
    
    # Check for sshpass
    if ! command -v sshpass &> /dev/null; then
        log_message "❌ sshpass: NOT INSTALLED (Required for SSH connections)"
        echo "❌ sshpass: NOT INSTALLED (Required for SSH connections)"
        missing_packages=$((missing_packages + 1))
    else
        log_message "✅ sshpass: Installed"
        echo "✅ sshpass: Installed"
    fi
    
    # Check for curl (Discord notifications)
    if ! command -v curl &> /dev/null; then
        log_message "❌ curl: NOT INSTALLED (Required for Discord notifications)"
        echo "❌ curl: NOT INSTALLED (Required for Discord notifications)"
        missing_packages=$((missing_packages + 1))
    else
        log_message "✅ curl: Installed"
        echo "✅ curl: Installed"
    fi
    
    # Check for email utilities
    if command -v msmtp &> /dev/null; then
        log_message "✅ msmtp: Installed (Preferred for email notifications)"
        echo "✅ msmtp: Installed (Preferred for email notifications)"
    elif command -v sendmail &> /dev/null; then
        log_message "✅ sendmail: Installed"
        echo "✅ sendmail: Installed"
    elif command -v mail &> /dev/null; then
        log_message "✅ mail: Installed"
        echo "✅ mail: Installed"
    else
        log_message "❌ No mail utility found (Required for email notifications)"
        echo "❌ No mail utility found (Required for email notifications)"
        missing_packages=$((missing_packages + 1))
    fi
    
    # Summary
    if [ $missing_packages -eq 0 ]; then
        log_message "All required packages are installed!"
        echo -e "\n✅ All required packages are installed!"
    else
        log_message "Missing $missing_packages required package(s)"
        echo -e "\n❌ Missing $missing_packages required package(s). Please install them using:"
        echo "   apt-get install sshpass curl msmtp"
    fi
    
    # Check router connectivity if all essential packages are available
    if command -v sshpass &> /dev/null; then
        echo -e "\nChecking MikroTik router connectivity..."
        if execute_ssh_command "/system identity print" &> /dev/null; then
            echo "✅ Successfully connected to router at $ROUTER_IP"
        else
            echo "❌ Failed to connect to router at $ROUTER_IP"
            echo "   Please check your SSH settings and router credentials"
        fi
    fi
    
    exit $missing_packages
}

# Function to send test notifications
test_notifications() {
    log_message "Sending test notifications..."
    echo "Sending test notifications..."
    
    local test_ip="192.0.2.1"  # TEST-NET-1 address from RFC 5737
    local test_direction="inbound"
    local test_power="1000"
    
    # Test Discord notification
    if [ -n "$DISCORD_WEBHOOK_URL" ] && [ "$DISCORD_WEBHOOK_URL" != "YOUR_DISCORD_WEBHOOK_URL_HERE" ]; then
        echo "Testing Discord notification..."
        send_discord_alert "test" "$test_ip" "$test_direction" "$test_power"
        
        if [ $? -eq 0 ]; then
            echo "✅ Discord notification test sent. Please check your Discord channel."
        else
            echo "❌ Discord notification test failed. Check your logs and webhook URL."
        fi
    else
        echo "❌ Discord webhook URL not configured. Skipping Discord notification test."
    fi
    
    # Test Email notification
    if [ "$EMAIL_NOTIFICATIONS_ENABLED" = "yes" ]; then
        if [ "$SMTP_SERVER" != "smtp.gmail.com" ] || [ "$SMTP_USER" != "your-email@gmail.com" ]; then
            echo "Testing Email notification..."
            send_email_alert "test" "$test_ip" "$test_direction" "$test_power"
            
            if [ $? -eq 0 ]; then
                echo "✅ Email notification test sent. Please check your inbox."
            else
                echo "❌ Email notification test failed. Check your logs and SMTP settings."
            fi
        else
            echo "❌ Email settings not configured. Skipping Email notification test."
        fi
    else
        echo "❌ Email notifications are disabled. Skipping Email notification test."
    fi
    
    exit 0
}

# Parse special command line arguments first
if [ "$1" = "--check-packages" ]; then
    check_packages
    exit $?
elif [ "$1" = "--check-notifications" ]; then
    test_notifications
    exit $?
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "FastNetMon MikroTik Integration Script"
    echo ""
    echo "Usage:"
    echo "  $0 [IP] [data_direction] [pps_as_string] [action]    Run the script normally with FastNetMon"
    echo "  $0 --check-packages                                  Check for required packages"
    echo "  $0 --check-notifications                             Test the notification systems"
    echo "  $0 --help                                            Show this help message"
    echo ""
    exit 0
fi

# Check if we have enough arguments
if [ $# -lt 4 ]; then
    log_message "ERROR: Not enough arguments provided"
    log_message "Usage: $0 [IP] [data_direction] [pps_as_string] [action]"
    exit 1
fi

# Parse arguments
ATTACK_IP="$1"
DIRECTION="$2"
POWER="$3"
ACTION="$4"

# Validate IP address
if [[ ! $ATTACK_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_message "ERROR: Invalid IP address format: $ATTACK_IP"
    exit 1
fi

# Validate action
if [[ "$ACTION" != "ban" && "$ACTION" != "unban" ]]; then
    log_message "ERROR: Invalid action: $ACTION. Must be 'ban' or 'unban'"
    exit 1
fi

# Log the action we're taking
log_message "Preparing to $ACTION IP $ATTACK_IP (direction: $DIRECTION, power: $POWER)"

# Check for existing routes first
execute_ssh_command "/ip route print where dst-address=$ATTACK_IP/32"

# Remove any existing routes for this IP
execute_ssh_command "/ip route remove [find where dst-address=$ATTACK_IP/32]"

if [ "$ACTION" = "ban" ]; then
    # Create timestamp for comment
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    COMMENT="FastNetMon: $ATTACK_IP blocked - $DIRECTION attack ($POWER pps) at $TIMESTAMP"
    
    # Add the blackhole route with final correct syntax
    execute_ssh_command "/ip route add dst-address=$ATTACK_IP/32 blackhole comment=\"$COMMENT\""
    
    # Set BGP communities in a separate command
    execute_ssh_command "/ip route set [find where dst-address=$ATTACK_IP/32 and type=blackhole] bgp-communities=65535:666"
    
    # Log to router syslog
    execute_ssh_command "/log info \"$COMMENT\""
    
    # Send notifications
    send_discord_alert "ban" "$ATTACK_IP" "$DIRECTION" "$POWER"
    
    # Send email notification if enabled
    if [ "$EMAIL_NOTIFICATIONS_ENABLED" = "yes" ]; then
        send_email_alert "ban" "$ATTACK_IP" "$DIRECTION" "$POWER"
    fi
    
else
    # Unban - just log that we removed the route
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    COMMENT="FastNetMon: $ATTACK_IP unbanned at $TIMESTAMP"
    
    # Log to router syslog
    execute_ssh_command "/log info \"$COMMENT\""
    
    # Send notifications
    send_discord_alert "unban" "$ATTACK_IP" "$DIRECTION" "$POWER"
    
    # Send email notification if enabled
    if [ "$EMAIL_NOTIFICATIONS_ENABLED" = "yes" ]; then
        send_email_alert "unban" "$ATTACK_IP" "$DIRECTION" "$POWER"
    fi
fi

log_message "Operation completed successfully"
exit 0
