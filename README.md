# Spring Boot Hot-Reload

## How It Works

Spring Boot applications are designed to run continuously on a specific port. For development purposes, automatic reloading when code changes is essential. This is achieved through two complementary scripts:

### **watch-kill.sh**

This script continuously monitors a target directory for changes. When it detects any modifications, it automatically terminates the process running on the specified port.

### **loop-run.sh**

This script operates in a continuous cycle, executing the specified command repeatedly. It is specifically designed to work with Spring Boot applications. When the port being used by your application is terminated by `watch-kill.sh`, this script automatically re-executes the command to restart the application.

## The Underlying Mechanism

Spring Boot applications maintain a strong connection with their designated port. The application will shut down if:
- Another process takes over the port
- The application is manually stopped
- An external process terminates the port connection

Since a Spring Boot server process continues running until completion, the next execution command in `loop-run.sh` remains pending until the current process is terminated. This creates a dependency: the command only re-executes when the port becomes available again, which occurs when the Spring Boot process stops.

By identifying and terminating the process occupying the designated port, we effectively create a mechanism that stops and restarts the Spring Boot application as needed.

The combination of these three elements—`loop-run.sh`, `watch-kill.sh`, and the `Spring Boot server process`—creates an efficient automatic hot-reloading system that restarts your application whenever code changes are detected.  

## Key Features

- Automatic rebuilding and restarting after file changes
- Desktop notifications for build status (success/failure)
- Intelligent error handling with adaptive retry intervals
- Detailed logging of build processes
- Configurable parameters for notification behavior and error thresholds

## Usage Example

Terminal 1:
```bash
./loop-run.sh 'mvn clean spring-boot:run'
```

Terminal 2:
```bash
./watch-kill.sh 8080 ./src
```

## Requirements

- Linux environment with Bash
- `inotify-tools` package for file system monitoring
- `notify-send` for desktop notifications (optional)

Perfect for developers who want the benefits of hot-reloading without the overhead of dedicated frameworks or plugins.
