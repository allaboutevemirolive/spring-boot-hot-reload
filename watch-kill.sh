#!/bin/bash
# ===========================================================================
# File: watch-kill.sh
# Description: Monitors directory changes and kills processes on specified port
# Usage: ./watch-kill.sh <port> [directory]
# Example: ./watch-kill.sh 8761 /path/to/your/project
# ===========================================================================

# This script monitors the target directory and kills the specified port.
# This script is intended for use with `loop-run.sh`.

# -----------------------------
# Configuration Variables
# -----------------------------
PORT=""
WATCH_DIR=""
WATCH_TIMEOUT=300  # Timeout for inotifywait in seconds
SLEEP_AFTER_KILL=5 # Sleep time after killing a process

# -----------------------------
# Function Definitions
# -----------------------------

# Display usage information
show_usage() {
    echo "Usage: $0 <port> [directory]"
    echo "Example: $0 8761 /path/to/your/project"
    echo
    echo "This script monitors the target directory and kills processes on the specified port."
    echo "It is intended for use with 'loop-run.sh' to enable auto hot-reloading."
}

# Initialize environment
initialize_environment() {
    # Enable alias expansion and load aliases
    shopt -s expand_aliases
    if [ -f ~/.bash_aliases ]; then
        source ~/.bash_aliases
    fi
    
    # Check if inotifywait is installed
    if ! command -v inotifywait &> /dev/null; then
        echo "Error: inotifywait not found. Please install inotify-tools."
        exit 1
    fi
}

# Process and validate command line arguments
process_arguments() {
    # Check for port argument
    if [ -z "$1" ]; then
        show_usage
        exit 1
    fi

    PORT="$1"
    WATCH_DIR="${2:-.}"  # Use provided directory or default to current directory

    # Ensure we're using absolute path for the watch directory
    WATCH_DIR="$(cd "$(dirname "$WATCH_DIR")" && pwd)/$(basename "$WATCH_DIR")"
    
    # Verify directory exists
    if [ ! -d "$WATCH_DIR" ]; then
        echo "Error: Directory '$WATCH_DIR' does not exist."
        exit 1
    fi
}

# Display startup information
display_startup_info() {
    echo "=============================================="
    echo "Directory Watch and Port Kill Utility"
    echo "=============================================="
    echo "Watching directory: $WATCH_DIR for file changes"
    echo "Will kill process running on port: $PORT after each change"
    echo "Waiting $SLEEP_AFTER_KILL seconds between executions"
    echo "=============================================="
}

# Kill process running on specific port
kill_port_process() {
    local port="$1"
    local pid=$(lsof -ti :"$port")
    
    if [ -n "$pid" ]; then
        echo "Change detected: Killing process $pid on port $port..."
        kill -9 "$pid" 2>/dev/null
        return 0
    else
        echo "Change detected: No process found on port $port."
        return 1
    fi
}

# Verify watch directory still exists
verify_directory() {
    if [ ! -d "$WATCH_DIR" ]; then
        echo "Error: Watch directory no longer exists. Waiting for it to become available..."
        sleep 10
        
        # If directory is still unavailable after waiting, exit with error
        if [ ! -d "$WATCH_DIR" ]; then
            echo "Error: Watch directory is permanently unavailable. Exiting."
            exit 1
        fi
    fi
}

# Main watch loop
run_watch_loop() {
    while true; do
        # Use timeout with inotifywait to prevent hanging
        if inotifywait -r -e modify,create,delete,move --timeout $WATCH_TIMEOUT "$WATCH_DIR" >/dev/null 2>&1; then
            # Successfully detected a file change event
            kill_port_process "$PORT"
            sleep $SLEEP_AFTER_KILL
        else
            # Handle inotifywait exit codes
            exit_code=$?
            if [ $exit_code -eq 2 ]; then
                echo "No file changes detected in the last $(($WATCH_TIMEOUT/60)) minutes. Continuing to watch..."
            else
                echo "inotifywait encountered an issue (exit code: $exit_code). Restarting watch..."
                sleep 2
            fi
        fi
        
        # Verify directory still exists
        verify_directory
    done
}

# -----------------------------
# Main Script Execution
# -----------------------------
initialize_environment
process_arguments "$@"
display_startup_info
run_watch_loop
