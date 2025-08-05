# Logging Config Module Documentation

## Overview

The Logging Config module provides functions for setting up and configuring logging throughout the 3-30-300 analysis framework. This module handles log file creation, log level configuration, and standardized logging format for consistent debugging and monitoring across all analysis components.

## Module Information

::: src.utils.logging_config
    handler: python
    selection:
      members:
        - setup_logger
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for logging configuration involves:

1. **Logger setup** - Configuring logging with file path and log level
2. **Log file creation** - Creating log files with standardized format
3. **Log level configuration** - Setting appropriate logging verbosity
4. **Application logging** - Using configured logger throughout application

### Example: Setting up Logger

```python
from src.utils.logging_config import setup_logger
import logging
from pathlib import Path

# Set up logger with custom log file
log_path = Path("logs/analysis.log")
setup_logger(log_path, logging.INFO)

# Use logger in application
logging.info("Analysis started")
logging.debug("Processing data...")
logging.warning("Memory usage high")
logging.error("Failed to process file")
```

### Example: Different Log Levels

```python
from src.utils.logging_config import setup_logger
import logging

# Debug level - most verbose
setup_logger("logs/debug.log", logging.DEBUG)

# Info level - standard information
setup_logger("logs/info.log", logging.INFO)

# Warning level - only warnings and errors
setup_logger("logs/warning.log", logging.WARNING)

# Error level - only errors
setup_logger("logs/error.log", logging.ERROR)
```

### Example: Application Integration

```python
from src.utils.logging_config import setup_logger
import logging
from pathlib import Path

# Set up logging for analysis module
log_path = Path("logs/t30_analysis.log")
setup_logger(log_path, logging.INFO)

# Use in analysis functions
def process_data():
    logging.info("Starting data processing")
    try:
        # Processing code here
        logging.debug("Data processed successfully")
    except Exception as e:
        logging.error(f"Error processing data: {e}")
        raise
```

## Logging Configuration

### Log File Settings

- **File Mode**: Append mode (`"a"`) to preserve existing logs
- **Encoding**: UTF-8 encoding for international character support
- **Format**: Standardized timestamp and log level format
- **Date Format**: ISO-style date and time format

### Log Level Hierarchy

1. **DEBUG**: Most verbose, includes all log messages
2. **INFO**: Standard information messages
3. **WARNING**: Warning messages (default level)
4. **ERROR**: Error messages only
5. **CRITICAL**: Critical errors only

### Log Format

```
2024-01-15 14:30 - INFO - Analysis started
2024-01-15 14:30 - DEBUG - Processing data...
2024-01-15 14:31 - WARNING - Memory usage high
2024-01-15 14:32 - ERROR - Failed to process file
```

## Key Parameters

### Logger Setup Parameters

- **log_path**: File path where log file will be saved
- **log_level**: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- **filemode**: File mode for log file ("a" for append)
- **encoding**: Character encoding for log file (UTF-8)
- **format**: Log message format string
- **datefmt**: Date and time format string

### Log Format Components

- **%(asctime)s**: Timestamp of log message
- **%(levelname)s**: Log level (DEBUG, INFO, etc.)
- **%(message)s**: Actual log message content
- **%(name)s**: Logger name (if specified)
- **%(filename)s**: Source file name
- **%(lineno)d**: Line number in source file

## Log File Management

### File Organization

- **Log Directory**: Centralized log storage location
- **File Naming**: Descriptive log file names by component
- **Rotation**: Append mode preserves historical logs
- **Archiving**: Manual log file archiving for long-term storage

### Log File Structure

```
logs/
├── t3_analysis.log
├── t30_analysis.log
├── t300_analysis.log
├── spectral_analysis.log
├── tree_count_analysis.log
└── general_analysis.log
```

## Logging Best Practices

### Log Level Usage

- **DEBUG**: Detailed information for debugging
- **INFO**: General information about program execution
- **WARNING**: Warning messages for potential issues
- **ERROR**: Error messages for actual problems
- **CRITICAL**: Critical errors that may cause program failure

### Message Content

- **Descriptive**: Clear and informative messages
- **Contextual**: Include relevant data and context
- **Actionable**: Provide information for troubleshooting
- **Consistent**: Use consistent terminology and format

### Performance Considerations

- **File I/O**: Logging can impact performance with high volume
- **Memory Usage**: Large log files can consume disk space
- **Network**: Distributed logging may require network bandwidth
- **Rotation**: Consider log file rotation for long-running processes

## Integration with Analysis Modules

### T3 Module Logging

```python
from src.utils.logging_config import setup_logger
import logging

# Set up T3-specific logging
setup_logger("logs/t3_analysis.log", logging.INFO)

def process_t3_data():
    logging.info("Starting T3 tree count analysis")
    # Analysis code here
    logging.info("T3 analysis completed")
```

### T30 Module Logging

```python
from src.utils.logging_config import setup_logger
import logging

# Set up T30-specific logging
setup_logger("logs/t30_analysis.log", logging.INFO)

def process_t30_data():
    logging.info("Starting T30 canopy cover analysis")
    # Analysis code here
    logging.info("T30 analysis completed")
```

### T300 Module Logging

```python
from src.utils.logging_config import setup_logger
import logging

# Set up T300-specific logging
setup_logger("logs/t300_analysis.log", logging.INFO)

def process_t300_data():
    logging.info("Starting T300 park distance analysis")
    # Analysis code here
    logging.info("T300 analysis completed")
```

## Error Handling

The module includes comprehensive error handling for:

- **File permissions**: Handles log file creation permissions
- **Disk space**: Manages log file size and disk usage
- **Encoding issues**: Handles character encoding problems
- **Path issues**: Validates log file paths and directories

## Dependencies

This module requires:

- `logging` for Python logging functionality
- `pathlib` for cross-platform path handling
- Python 3.6+ for f-string support

## Notes

- The module provides standardized logging across all analysis components
- Log files use append mode to preserve historical information
- UTF-8 encoding ensures international character support
- Standardized format enables easy log parsing and analysis
- Log levels can be adjusted based on development vs production needs
- The module supports both local and distributed logging scenarios
- Comprehensive error handling ensures robust logging operation
