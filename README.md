# Spring Boot Hot-Reload

Spring Boot applications are designed to run continuously on a specific port. For development purposes, automatic reloading when code changes is essential. This is achieved through two complementary scripts:

### **watch-kill.sh**  

This script continuously monitors a target directory for changes. When a modification is detected, it automatically terminates the process running on the specified port.  

You must manually specify the port used by the Spring project you are running.  

Currently, if you need to stop `loop-run.sh` for any reason, you must restart `watch-kill.sh`.

### **loop-run.sh**

This script operates in a continuous cycle, executing the specified command repeatedly. It is specifically designed to work with Spring Boot applications. When the port being used by your application is terminated by `watch-kill.sh`, this script automatically re-executes the command to restart the application.

## Usage Example

Terminal 1:
```bash
./loop-run.sh --path /path/to/spring_project 'mvn clean spring-boot:run'
```

Terminal 2:
```bash
# Change 8761 with the port used by this Spring Boot application
./watch-kill.sh 8761 /path/to/spring_project
```

## The Underlying Mechanism

Spring Boot applications maintain a strong connection with their designated port. The application will shut down if:
- Another process takes over the port
- The application is manually stopped
- An external process terminates the port connection

Since a Spring Boot server process continues running until completion, the next execution command in `loop-run.sh` remains pending until the current process is terminated. This creates a dependency: the command only re-executes when the port becomes available again, which occurs when the Spring Boot process stops.

By identifying and terminating the process occupying the designated port, we effectively create a mechanism that stops and restarts the Spring Boot application as needed.

## Key Features

- Automatic rebuilding and restarting after file changes
- Desktop notifications for build status (success/failure)
- Intelligent error handling with adaptive retry intervals
- Detailed logging of build processes
- Configurable parameters for notification behavior and error thresholds

## Requirements

- Linux environment with Bash
- `inotify-tools` package for file system monitoring
- `notify-send` for desktop notifications (optional)

## License

This project is open source and available under the [MIT License](LICENSE).
