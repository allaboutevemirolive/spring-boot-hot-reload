#!/bin/bash
# Usage: ./watch_and_kill.sh <port> [directory]
# Example: ./watch_and_kill.sh 8761 /path/to/your/project

# This script monitors the target directory and kills the specified port.
# This script is intended for use with `loop-run.sh`.

# Enable alias expansion and load aliases
shopt -s expand_aliases
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# Check for port argument
if [ -z "$1" ]; then
    echo "Usage: $0 <port> [directory]"
    exit 1
fi

PORT="$1"
WATCH_DIR="${2:-.}"  # Use provided directory or default to current directory

# Ensure we're using absolute path for the watch directory
WATCH_DIR="$(cd "$(dirname "$WATCH_DIR")" && pwd)/$(basename "$WATCH_DIR")"

echo "Watching directory: $WATCH_DIR for file changes..."
echo "Will kill process running on port: $PORT (if owned by you) after each change."
echo "Waiting 5 seconds between executions..."

# Check if inotifywait is installed
if ! command -v inotifywait &> /dev/null; then
    echo "Error: inotifywait not found. Please install inotify-tools."
    exit 1
fi

# Function to kill process on specific port
kill_port_process() {
    local port="$1"
    PID=$(lsof -ti :"$port")
    if [ -n "$PID" ]; then
        echo "Detected change: killing process $PID on port $port..."
        kill -9 "$PID" 2>/dev/null
        return 0
    else
        echo "Detected change: no process found on port $port."
        return 1
    fi
}

# Main loop with error handling
while true; do
    # Use a timeout with inotifywait to prevent it from hanging indefinitely
    # The --timeout option makes it exit after a certain period if no events occur
    if inotifywait -r -e modify,create,delete,move --timeout 300 "$WATCH_DIR" >/dev/null 2>&1; then
        # Successfully detected a file change event
        kill_port_process "$PORT"
        sleep 5
    else
        # inotifywait timed out or encountered an error
        exit_code=$?
        if [ $exit_code -eq 2 ]; then
            # Timeout occurred (no events within the specified time)
            echo "No file changes detected in the last 5 minutes. Continuing to watch..."
        else
            # Handle any other errors
            echo "inotifywait encountered an issue (exit code: $exit_code). Restarting watch..."
            sleep 2
        fi
    fi
    
    # Verify the watch directory still exists
    if [ ! -d "$WATCH_DIR" ]; then
        echo "Error: Watch directory no longer exists. Waiting for it to become available..."
        sleep 10
        
        # If directory is still unavailable after waiting, exit with error
        if [ ! -d "$WATCH_DIR" ]; then
            echo "Error: Watch directory is permanently unavailable. Exiting."
            exit 1
        fi
    fi
done