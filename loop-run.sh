#!/bin/bash

# This script continuously executes the command and is intended for use with
# Spring Boot.
# 
# Due to the nature of the Spring Boot server process, the next command won't
# run until the current process's port is either terminated or taken over by
# another process.
#
# The command is only re-run once the port becomes unavailable, which creates
# a hot-reloading effect for Spring Boot.
# 
# Please refer to the `watch-kill.sh` script, which monitors the target
# directory for file changes and terminates the process using that port.
#
# The combination of loop-run, watch-kill, and the Spring Boot server
# process enables auto hot-reloading.

# Enable alias expansion and load aliases
shopt -s expand_aliases
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# ===========================
# Configurations
# ===========================
# Delay interval (seconds) between each run
DELAY_INTERVAL=5
# Log file (optional, set to empty string to disable logging)
LOG_FILE="build-loop.log"
# Maximum number of consecutive errors before requiring manual intervention
MAX_CONSECUTIVE_ERRORS=3
# Enable desktop notifications (true/false)
ENABLE_NOTIFICATIONS=true
# Notification timeout in milliseconds
NOTIFICATION_TIMEOUT=10000

# ===========================
# Helper Functions
# ===========================
# Get current directory name
get_current_dir() {
    basename "$(pwd)"
}

# Log messages with timestamps
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message"
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
    fi
}

# Send desktop notification using notify-send (for MATE Debian)
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3"  # "low", "normal", or "critical"
    local current_dir=$(get_current_dir)
    
    # Add current directory to both title and message
    local enhanced_title="[$current_dir] $title"
    local enhanced_message="$message\nDirectory: $current_dir"
    
    if [[ "$ENABLE_NOTIFICATIONS" == "true" ]]; then
        if command -v notify-send &> /dev/null; then
            notify-send --urgency="$urgency" --expire-time="$NOTIFICATION_TIMEOUT" "$enhanced_title" "$enhanced_message"
            log_message "Notification sent: $enhanced_title - $enhanced_message"
        else
            log_message "Warning: notify-send command not found. Cannot display desktop notifications."
        fi
    fi
}

# Display usage and exit
usage() {
    echo "Usage: $0 <command>"
    echo "Arguments:"
    echo "  command      Command to run continuously"
    echo ""
    echo "Examples:"
    echo "  $0 'mvn clean spring-boot:run'"
    echo "  $0 'npm start'"
    exit 1
}

# Wait for user confirmation to continue after errors
wait_for_user_confirmation() {
    local current_dir=$(get_current_dir)
    send_notification "Build Process Paused" "Too many consecutive errors in $current_dir. Waiting for your input to continue." "critical"
    read -p "Press Enter to continue or Ctrl+C to exit..."
    error_count=0
}

# ===========================
# Script Logic
# ===========================
# Validate script arguments
if [[ $# -ne 1 ]]; then
    log_message "Error: Command is required."
    usage
fi

BUILD_COMMAND="$1"
error_count=0
error_output_file=$(mktemp)
last_build_successful=false
current_dir=$(get_current_dir)

log_message "Starting continuous build loop in directory: $current_dir"
log_message "Will continuously run '$BUILD_COMMAND' with a delay of $DELAY_INTERVAL seconds between runs."

# Main loop to continuously run the build command
while true; do
    send_notification "Building" "Building and running the current project." "low"

    # Clear the terminal before running the build command
    clear

    # Run the build command and capture output
    log_message "Running command in $current_dir: $BUILD_COMMAND"
    eval "$BUILD_COMMAND" 2>&1 | tee "$error_output_file"
    
    # Check for error patterns in the output
    # We exclude "BUILD FAILURE" from the check because it can also indicate
    # that the port was killed due to changes made in the source file. 
    if grep -q "COMPILATION ERROR" "$error_output_file"; then
        error_count=$((error_count + 1))
        last_build_successful=false
        
        # Extract error details for notification
        error_details=$(grep -A 5 "COMPILATION ERROR" "$error_output_file" | head -n 6)
        
        log_message "Build error detected in $current_dir. Consecutive errors: $error_count/$MAX_CONSECUTIVE_ERRORS"
        
        # Send desktop notification
        send_notification "Spring Boot Build Error" "Compilation error detected. Check your code." "normal"
        
        # If max consecutive errors reached, require manual intervention
        if [[ $error_count -ge $MAX_CONSECUTIVE_ERRORS ]]; then
            log_message "Maximum consecutive errors ($MAX_CONSECUTIVE_ERRORS) reached in $current_dir. Pausing auto-run."
            wait_for_user_confirmation
        else
            # Increase the delay for the next run after an error
            actual_delay=$((DELAY_INTERVAL * error_count))
            log_message "Waiting $actual_delay seconds before next attempt..."
            sleep "$actual_delay"
        fi
    else
        # Check if the build was successful
        if grep -q "BUILD FAILURE" "$error_output_file"; then
            # Reset error count on successful build and send notification
            if [[ $error_count -gt 0 ]]; then
                log_message "Build successful in $current_dir. Resetting error counter."
                send_notification "Build Successful" "Previous errors have been resolved." "low"
                error_count=0
                last_build_successful=true
            elif [[ "$last_build_successful" == "false" ]]; then
                # First successful build or after a restart
                log_message "Build successful in $current_dir."
                # send_notification "Build Successful" "Application built and running successfully." "low"
                last_build_successful=true
            else
                log_message "Command completed successfully in $current_dir!"
                # send_notification "Build Successful" "Application built and running successfully." "low"
            fi
        else
            # This might be a port killed situation, not a real build failure
            log_message "Command completed with potential issues in $current_dir."
            last_build_successful=false
        fi
        
        # Wait for the specified delay before the next run
        log_message "Waiting $DELAY_INTERVAL seconds before next run..."
        sleep "$DELAY_INTERVAL"
    fi
    
    # Clean up temporary file
    rm -f "$error_output_file"
done