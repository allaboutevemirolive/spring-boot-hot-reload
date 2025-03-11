# Spring Boot Hot-Reload Utilities

A pair of complementary Bash scripts that enable seamless hot-reloading for Spring Boot applications during development.

## Overview

This repository contains two utility scripts that work together to provide an efficient development workflow:

- **loop-run.sh**: Continuously executes your Spring Boot application with intelligent error handling
- **watch-kill.sh**: Monitors your project directory for changes and terminates the application process to trigger rebuilds

## How It Works  

### **watch-kill.sh**  
This script continuously monitors the target directory and kills the specified port whenever changes are detected.  

### **loop-run.sh**  
This script continuously executes the command and is designed for use with Spring Boot. Once the used port is killed by `watch-kill.sh`, this script will re-run the specified command.

Take note, Spring Boot applications are tightly coupled with the port they run on. If the port is no longer available—whether due to another process taking it, the application being stopped, or an external force killing it—Spring Boot will shut down.

Since the Spring Boot server process keeps running, the next command won't execute until the current process's port is either terminated or taken over by another process.  

So, the command is re-run only when the port becomes unavailable—meaning the Spring Boot server process has stopped—creating a hot-reloading effect.  

Using the trick of finding and killing the process that holds the port, we create a script that essentially stops our Spring Boot application and restarts it when needed. 

By combining `loop-run`, `watch-kill`, and the Spring Boot server process, we achieve automatic hot-reloading.

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
