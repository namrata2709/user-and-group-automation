#!/bin/bash

# Load and validate configuration
load_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "ERROR: Configuration file not found: $config_file"
        return 1
    fi
    
    # Source the config file
    source "$config_file"
    
    # Validate required variables
    local required_vars=(
        "DEFAULT_PASSWORD"
        "PASSWORD_LENGTH"
        "PASSWORD_EXPIRY_DAYS"
        "PASSWORD_WARN_DAYS"
        "ENCRYPTION_KEY"
        "LOG_FILE"
        "BACKUP_DIR"
        "DEFAULT_SHELL"
        "SUDO_GROUP"
        "DEFAULT_SUDO"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "ERROR: Missing required configuration variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please check: $config_file"
        return 1
    fi
    
    # Validate shell role mappings exist
    local shell_roles=(
        "SHELL_ROLE_ADMIN"
        "SHELL_ROLE_DEVELOPER"
        "SHELL_ROLE_SUPPORT"
        "SHELL_ROLE_INTERN"
        "SHELL_ROLE_MANAGER"
        "SHELL_ROLE_CONTRACTOR"
    )
    
    for var in "${shell_roles[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "ERROR: Missing shell role mappings:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        return 1
    fi
    
    # Validate critical paths exist
    if [ ! -d "$(dirname "$LOG_FILE")" ]; then
        echo "WARNING: Log directory does not exist: $(dirname "$LOG_FILE")"
        echo "Will be created on first use"
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "WARNING: Backup directory does not exist: $BACKUP_DIR"
        echo "Will be created on first use"
    fi
    
    return 0
}

# Display configuration summary
show_config() {
    echo "Configuration Summary:"
    echo "  Config File:        $CONFIG_FILE"
    echo "  Log File:           $LOG_FILE"
    echo "  Backup Directory:   $BACKUP_DIR"
    echo "  Default Shell:      $DEFAULT_SHELL"
    echo "  Sudo Group:         $SUDO_GROUP"
    echo "  Password Length:    $PASSWORD_LENGTH chars"
    echo "  Password Expiry:    $PASSWORD_EXPIRY_DAYS days"
    echo "  Password Warning:   $PASSWORD_WARN_DAYS days"
}