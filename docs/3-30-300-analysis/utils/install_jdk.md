# Install JDK Module Documentation

## Overview

The Install JDK module provides functions for automatically installing and configuring the Java Development Kit (JDK) required for Apache Spark and Sedona spatial processing. This module handles JDK installation, version management, and path configuration for the 3-30-300 analysis framework.

## Module Information

::: src.utils.install_jdk
    handler: python
    selection:
      members:
        - install_jdk
    rendering:
      show_source: true
      show_root_heading: true
      show_category_heading: true

## Usage Examples

### Basic Workflow

The typical workflow for JDK installation involves:

1. **JDK installation** - Installing the specified JDK version
2. **Path configuration** - Setting up JAVA_HOME environment variable
3. **Version verification** - Ensuring correct JDK version is installed
4. **Spark integration** - Configuring Spark to use the installed JDK

### Example: Installing JDK 8

```python
from src.utils.install_jdk import install_jdk

# Install JDK 8 (default)
jdk_path = install_jdk(version='8')

print(f"JDK installed at: {jdk_path}")
```

### Example: Installing Specific JDK Version

```python
from src.utils.install_jdk import install_jdk

# Install JDK 11
jdk_path = install_jdk(version='11', path='/opt/java')

print(f"JDK 11 installed at: {jdk_path}")
```

### Example: Custom Installation Path

```python
from src.utils.install_jdk import install_jdk
from pathlib import Path

# Install JDK 8 to custom path
custom_path = Path("/opt/java/jdk8")
jdk_path = install_jdk(version='8', path=str(custom_path))

print(f"JDK installed at: {jdk_path}")
```

## JDK Requirements

### Apache Spark Requirements

- **Java 8 or higher**: Required for Apache Spark
- **JAVA_HOME**: Must be set to JDK installation directory
- **Compatibility**: Must be compatible with Spark version
- **Architecture**: Must match system architecture (x64, ARM, etc.)

### Apache Sedona Requirements

- **Java 8+**: Minimum requirement for Sedona
- **Memory**: Sufficient memory for spatial operations
- **Performance**: Optimized JDK for large-scale processing
- **Stability**: Stable JDK version for production use

## Key Parameters

### Installation Parameters

- **version**: JDK version to install (default: '8')
- **path**: Installation directory (default: JAVA_HOME from constants)
- **architecture**: System architecture (auto-detected)
- **distribution**: JDK distribution (OpenJDK, Oracle JDK, etc.)

### Supported Versions

- **JDK 8**: LTS version, widely supported
- **JDK 11**: LTS version, recommended for newer systems
- **JDK 17**: Latest LTS version
- **JDK 21**: Latest version (experimental)

## Installation Process

### Automatic Installation

1. **Version Detection**: Determines system requirements
2. **Download**: Downloads appropriate JDK distribution
3. **Installation**: Installs JDK to specified path
4. **Configuration**: Sets up environment variables
5. **Verification**: Validates installation success

### Path Configuration

- **JAVA_HOME**: Sets Java home directory
- **PATH**: Adds Java binaries to system path
- **Permissions**: Ensures proper file permissions
- **Symlinks**: Creates necessary symbolic links

## Environment Setup

### System Requirements

- **Operating System**: Linux, macOS, or Windows
- **Architecture**: x64, ARM64, or other supported architectures
- **Disk Space**: Sufficient space for JDK installation
- **Permissions**: Write permissions for installation directory

### Network Requirements

- **Internet Connection**: Required for JDK download
- **Proxy Support**: Handles corporate proxy configurations
- **Mirror Selection**: Uses appropriate download mirrors
- **Fallback**: Multiple download sources for reliability

## Integration with Spark

### Spark Configuration

```python
from src.utils.install_jdk import install_jdk
from src.utils.sedona_config import get_spark

# Install JDK if needed
jdk_path = install_jdk(version='8')

# Configure Spark with installed JDK
sedona = get_spark()
```

### Environment Variables

- **JAVA_HOME**: Points to JDK installation directory
- **SPARK_HOME**: Apache Spark installation directory
- **SEDONA_HOME**: Apache Sedona installation directory
- **PATH**: Includes Java and Spark binaries

## Error Handling

The module includes comprehensive error handling for:

- **Network issues**: Handles download failures and timeouts
- **Permission errors**: Manages file system permissions
- **Version conflicts**: Resolves JDK version compatibility
- **Disk space**: Validates available disk space
- **Installation failures**: Provides detailed error messages

## Performance Considerations

### Installation Time

- **Download time**: Depends on network speed and JDK size
- **Installation time**: Varies by system performance
- **Verification time**: Quick validation of installation
- **Total time**: Typically 5-15 minutes depending on system

### System Impact

- **Disk usage**: JDK installation requires 200-500MB
- **Memory usage**: Minimal during installation
- **Network usage**: Downloads 50-200MB depending on version
- **CPU usage**: Moderate during installation process

## Dependencies

This module requires:

- `jdk` Python package for JDK installation
- `pathlib` for cross-platform path handling
- `utils.constants` for default path configuration
- Internet connection for JDK download

## Troubleshooting

### Common Issues

- **Network timeout**: Check internet connection and proxy settings
- **Permission denied**: Ensure write permissions for installation directory
- **Version not found**: Verify supported JDK version
- **Path issues**: Check JAVA_HOME configuration

### Solutions

- **Retry installation**: Network issues may resolve with retry
- **Change installation path**: Use directory with proper permissions
- **Use different version**: Try alternative JDK version
- **Manual installation**: Fallback to manual JDK installation

## Notes

- The module provides automatic JDK installation for Spark/Sedona
- Supports multiple JDK versions and distributions
- Handles cross-platform installation requirements
- Includes comprehensive error handling and validation
- Integrates seamlessly with Spark and Sedona configuration
- Supports both development and production environments
- Automatic path configuration for immediate use

