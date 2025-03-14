#!/bin/bash
# ===========================================================================
# File: loop-run.sh
# Description: Continuously executes commands with error handling
# Usage: ./loop-run.sh [-p|--path <directory>] <command>
# Examples: 
#   ./loop-run.sh 'mvn clean spring-boot:run'
#   ./loop-run.sh --path /path/to/project 'mvn clean spring-boot:run'
# ===========================================================================

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

# -----------------------------
# Configuration Variables
# -----------------------------
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

# Command to execute repeatedly
BUILD_COMMAND=""
# Directory to execute the command in
TARGET_DIR=""

# State tracking variables
error_count=0
last_build_successful=false
error_output_file=""
original_dir=""

# -----------------------------
# Function Definitions
# -----------------------------

# Initialize environment
initialize_environment() {
    # Enable alias expansion and load aliases
    shopt -s expand_aliases
    if [ -f ~/.bash_aliases ]; then
        source ~/.bash_aliases
    fi
    
    # Create temporary file for error output
    error_output_file=$(mktemp)
    
    # Save original directory
    original_dir=$(pwd)
}

# Display usage information
show_usage() {
    echo "Usage: $0 [-p|--path <directory>] <command>"
    echo "Arguments:"
    echo "  -p, --path    Directory path where the command should be executed (optional)"
    echo "  command       Command to run continuously"
    echo ""
    echo "Examples:"
    echo "  $0 'mvn clean spring-boot:run'"
    echo "  $0 --path /path/to/project 'npm start'"
    exit 1
}

# Process and validate command line arguments
process_arguments() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--path)
                if [[ -z "$2" || "$2" == -* ]]; then
                    log_message "Error: Path option requires a directory argument."
                    show_usage
                fi
                TARGET_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                # If we've already set the command, error out
                if [[ -n "$BUILD_COMMAND" ]]; then
                    log_message "Error: Unexpected argument: $1"
                    show_usage
                fi
                BUILD_COMMAND="$1"
                shift
                ;;
        esac
    done

    # Validate command
    if [[ -z "$BUILD_COMMAND" ]]; then
        log_message "Error: Command is required."
        show_usage
    fi

    # Validate and normalize target directory
    if [[ -n "$TARGET_DIR" ]]; then
        # Ensure directory exists
        if [[ ! -d "$TARGET_DIR" ]]; then
            log_message "Error: Directory '$TARGET_DIR' does not exist."
            exit 1
        fi
        
        # Convert to absolute path
        TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
    else
        # Default to current directory
        TARGET_DIR="$(pwd)"
    fi
    
    # Create log file in the target directory if enabled
    if [[ -n "$LOG_FILE" ]]; then
        LOG_FILE="$TARGET_DIR/$LOG_FILE"
    fi
}

# Get current directory name
get_current_dir() {
    basename "$TARGET_DIR"
}

# Change to target directory
change_to_target_dir() {
    log_message "Changing to directory: $TARGET_DIR"
    cd "$TARGET_DIR" || {
        log_message "Error: Failed to change to directory $TARGET_DIR. Exiting."
        exit 1
    }
}

# Log messages with timestamps
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message"
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
    fi
}

# Send desktop notification
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3"  # "low", "normal", or "critical"
    local current_dir=$(get_current_dir)
    
    # Add current directory to both title and message
    local enhanced_title="[$current_dir] $title"
    local enhanced_message="$message\nDirectory: $TARGET_DIR"
    
    if [[ "$ENABLE_NOTIFICATIONS" == "true" ]]; then
        if command -v notify-send &> /dev/null; then
            notify-send --urgency="$urgency" --expire-time="$NOTIFICATION_TIMEOUT" "$enhanced_title" "$enhanced_message"
            log_message "Notification sent: $enhanced_title - $enhanced_message"
        else
            log_message "Warning: notify-send command not found. Cannot display desktop notifications."
        fi
    fi
}

# Wait for user confirmation after too many errors
wait_for_user_confirmation() {
    local current_dir=$(get_current_dir)
    send_notification "Build Process Paused" "Too many consecutive errors in $current_dir. Waiting for your input to continue." "critical"
    read -p "Press Enter to continue or Ctrl+C to exit..."
    error_count=0
}

# Display startup information
display_startup_info() {
    local current_dir=$(get_current_dir)
    
    echo "=============================================="
    echo "Continuous Build Loop Utility"
    echo "=============================================="
    echo "Directory: $TARGET_DIR"
    echo "Command: $BUILD_COMMAND"
    echo "Delay between runs: $DELAY_INTERVAL seconds"
    echo "Max consecutive errors: $MAX_CONSECUTIVE_ERRORS"
    if [[ -n "$LOG_FILE" ]]; then
        echo "Log file: $LOG_FILE"
    fi
    echo "=============================================="
    
    log_message "Starting continuous build loop in directory: $TARGET_DIR"
    log_message "Will continuously run '$BUILD_COMMAND' with a delay of $DELAY_INTERVAL seconds between runs."
}

# Handle build errors
handle_build_error() {
    error_count=$((error_count + 1))
    last_build_successful=false
    
    # Extract error details for notification
    error_details=$(grep -A 5 "COMPILATION ERROR" "$error_output_file" | head -n 6)
    
    log_message "Build error detected in $(get_current_dir). Consecutive errors: $error_count/$MAX_CONSECUTIVE_ERRORS"
    
    # Send desktop notification
    send_notification "Spring Boot Build Error" "Compilation error detected. Check your code." "normal"
    
    # If max consecutive errors reached, require manual intervention
    if [[ $error_count -ge $MAX_CONSECUTIVE_ERRORS ]]; then
        log_message "Maximum consecutive errors ($MAX_CONSECUTIVE_ERRORS) reached in $(get_current_dir). Pausing auto-run."
        wait_for_user_confirmation
    else
        # Increase the delay for the next run after an error
        actual_delay=$((DELAY_INTERVAL * error_count))
        log_message "Waiting $actual_delay seconds before next attempt..."
        sleep "$actual_delay"
    fi
}

# Handle build success
handle_build_success() {
    # Reset error count on successful build and send notification
    if [[ $error_count -gt 0 ]]; then
        log_message "Build successful in $(get_current_dir). Resetting error counter."
        send_notification "Build Successful" "Previous errors have been resolved." "low"
        error_count=0
        last_build_successful=true
    elif [[ "$last_build_successful" == "false" ]]; then
        # First successful build or after a restart
        log_message "Build successful in $(get_current_dir)."
        last_build_successful=true
    else
        log_message "Command completed successfully in $(get_current_dir)!"
    fi
}

# Handle possible build failure
handle_possible_failure() {
    # This might be a port killed situation, not a real build failure
    log_message "Command completed with potential issues in $(get_current_dir)."
    last_build_successful=false
}

# Run the main build command
run_build_command() {
    send_notification "Building" "Building and running the current project." "low"

    # Clear the terminal before running the build command
    clear

    # Run the build command and capture output
    log_message "Running command in $(get_current_dir): $BUILD_COMMAND"
    eval "$BUILD_COMMAND" 2>&1 | tee "$error_output_file"
    
    # Check for error patterns in the output
    if grep -q "COMPILATION ERROR" "$error_output_file"; then
        handle_build_error
    else
        # Check if the build was successful
        if grep -q "BUILD FAILURE" "$error_output_file"; then
            handle_build_success
        else
            handle_possible_failure
        fi
    fi
    
    # Wait for the specified delay before the next run
    log_message "Waiting $DELAY_INTERVAL seconds before next run..."
    sleep "$DELAY_INTERVAL"
}

# Cleanup temporary files and restore original directory
cleanup() {
    log_message "Cleaning up and exiting..."
    rm -f "$error_output_file"
    
    # Return to original directory
    cd "$original_dir" || true
    
    exit 0
}

# -----------------------------
# Main Script Execution
# -----------------------------
# Set up trap for cleanup on exit
trap cleanup EXIT INT TERM

# Initialize and start the loop
initialize_environment
process_arguments "$@"
change_to_target_dir
display_startup_info

# Main execution loop
while true; do
    run_build_command
done
