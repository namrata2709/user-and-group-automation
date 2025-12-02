#!/bin/bash

# ================================================
# System Installation and Validation Script
# File: install.sh
# ================================================
# This script runs on first execution to:
# 1. Check system requirements
# 2. Install missing shells per organization policy
# 3. Validate dependencies
# 4. Create necessary directories
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/opt/admin_dashboard/config/user_mgmt.conf"
INSTALL_MARKER="/opt/admin_dashboard/.installed"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ================================================
# Print colored messages
# ================================================
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ================================================
# Check if running as root
# ================================================
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
    print_success "Running as root"
}

# ================================================
# Load configuration file
# ================================================
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Configuration loaded from $CONFIG_FILE"
    else
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# ================================================
# Check and install required packages
# ================================================
check_dependencies() {
    print_info "Checking system dependencies..."
    
    local missing_deps=()
    local missing_python_deps=()
    local required_packages=("openssl" "jq" "python3")
    
    # Check system packages
    for pkg in "${required_packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_deps+=("$pkg")
        fi
    done
    
    # Install missing system packages
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_warning "Missing packages: ${missing_deps[*]}"
        print_info "Attempting to install missing packages..."
        
        if command -v yum &> /dev/null; then
            yum install -y "${missing_deps[@]}"
        elif command -v dnf &> /dev/null; then
            dnf install -y "${missing_deps[@]}"
        elif command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y "${missing_deps[@]}"
        else
            print_error "No supported package manager found (yum/dnf/apt)"
            exit 1
        fi
        
        print_success "Dependencies installed"
    else
        print_success "All system dependencies present"
    fi
    
    # Check pip3
    if ! command -v pip3 &> /dev/null; then
        print_info "Installing pip3..."
        
        if command -v yum &> /dev/null; then
            yum install -y python3-pip
        elif command -v dnf &> /dev/null; then
            dnf install -y python3-pip
        elif command -v apt-get &> /dev/null; then
            apt-get install -y python3-pip
        else
            print_error "Cannot install pip3"
            exit 1
        fi
    fi
    
    # Check Python packages
    print_info "Checking Python dependencies..."
    
    if ! python3 -c "import openpyxl" 2>/dev/null; then
        missing_python_deps+=("openpyxl")
    fi
    
    # Install missing Python packages
    if [ ${#missing_python_deps[@]} -gt 0 ]; then
        print_warning "Missing Python packages: ${missing_python_deps[*]}"
        print_info "Installing Python packages..."
        
        if pip3 install "${missing_python_deps[@]}" &>/dev/null; then
            print_success "Python packages installed"
        else
            print_error "Failed to install Python packages"
            print_warning "XLSX parsing will not work without openpyxl"
            echo ""
            print_info "You can install manually later:"
            print_info "  sudo pip3 install openpyxl"
            echo ""
            read -p "Continue anyway? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                print_error "Installation aborted"
                exit 1
            fi
        fi
    else
        print_success "All Python dependencies present"
    fi
}

# ================================================
# Get shell package name based on distro
# ================================================
get_shell_package() {
    local shell_path="$1"
    
    case "$shell_path" in
        /bin/bash|/usr/bin/bash)
            echo "bash"
            ;;
        /bin/zsh|/usr/bin/zsh)
            echo "zsh"
            ;;
        /bin/sh|/usr/bin/sh)
            echo ""  # sh is always present
            ;;
        /sbin/nologin|/usr/sbin/nologin)
            echo ""  # nologin is always present
            ;;
        /bin/ksh|/usr/bin/ksh)
            echo "ksh"
            ;;
        /bin/tcsh|/usr/bin/tcsh)
            echo "tcsh"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ================================================
# Check and install organization policy shells
# ================================================
check_organization_shells() {
    print_info "Checking organization policy shells..."
    
    local shells_to_check=(
        "$SHELL_ROLE_ADMIN"
        "$SHELL_ROLE_DEVELOPER"
        "$SHELL_ROLE_SUPPORT"
        "$SHELL_ROLE_INTERN"
        "$SHELL_ROLE_MANAGER"
    )
    
    local missing_shells=()
    local failed_installs=()
    
    # Remove duplicates
    local unique_shells=($(printf "%s\n" "${shells_to_check[@]}" | sort -u))
    
    for shell_path in "${unique_shells[@]}"; do
        if [ ! -x "$shell_path" ]; then
            print_warning "Shell not found: $shell_path"
            missing_shells+=("$shell_path")
            
            # Try to install
            local package=$(get_shell_package "$shell_path")
            if [ -n "$package" ]; then
                print_info "Attempting to install: $package"
                
                if command -v yum &> /dev/null; then
                    if yum install -y "$package" &> /dev/null; then
                        print_success "Installed: $package"
                    else
                        failed_installs+=("$shell_path")
                    fi
                elif command -v dnf &> /dev/null; then
                    if dnf install -y "$package" &> /dev/null; then
                        print_success "Installed: $package"
                    else
                        failed_installs+=("$shell_path")
                    fi
                elif command -v apt-get &> /dev/null; then
                    apt-get update &> /dev/null
                    if apt-get install -y "$package" &> /dev/null; then
                        print_success "Installed: $package"
                    else
                        failed_installs+=("$shell_path")
                    fi
                else
                    failed_installs+=("$shell_path")
                fi
            else
                failed_installs+=("$shell_path")
            fi
        else
            print_success "Shell available: $shell_path"
        fi
    done
    
    # Report failures
    if [ ${#failed_installs[@]} -gt 0 ]; then
        echo ""
        print_error "=================================="
        print_error "INSTALLATION FAILED"
        print_error "=================================="
        print_warning "The following shells required by organization policy could not be installed:"
        for shell in "${failed_installs[@]}"; do
            echo "  - $shell"
        done
        echo ""
        print_warning "Please install these shells manually or update your organization policy in:"
        print_warning "$CONFIG_FILE"
        echo ""
        print_info "To continue anyway, you can:"
        print_info "1. Install shells manually: yum/dnf/apt install <package>"
        print_info "2. Update SHELL_ROLE_* variables in config to use available shells"
        echo ""
        read -p "Continue anyway? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_error "Installation aborted"
            exit 1
        fi
    fi
}

# ================================================
# Create necessary directories
# ================================================
create_directories() {
    print_info "Creating necessary directories..."
    
    local directories=(
        "$BACKUP_DIR"
        "$BACKUP_DIR/passwords"
        "$(dirname "$LOG_FILE")"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            chmod 700 "$dir"  # Restrictive permissions
            print_success "Created directory: $dir"
        else
            print_success "Directory exists: $dir"
        fi
    done
}

# ================================================
# Initialize log file
# ================================================
# Initialize log file
initialize_log() {
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 600 "$LOG_FILE"
        echo "# User Management Audit Log" > "$LOG_FILE"
        echo "# Created: $(date)" >> "$LOG_FILE"
        print_success "Log file initialized: $LOG_FILE"
    else
        print_success "Log file exists: $LOG_FILE"
    fi
}

# ================================================
# Mark installation as complete
# ================================================
mark_installed() {
    mkdir -p "$(dirname "$INSTALL_MARKER")"
    date > "$INSTALL_MARKER"
    print_success "Installation marker created"
}

# ================================================
# Main installation process
# ================================================
main() {
    echo "================================================"
    echo "User Management System - Installation"
    echo "================================================"
    echo ""
    
    check_root
    load_config
    check_dependencies
    check_organization_shells
    create_directories
    initialize_log
    mark_installed
    
    echo ""
    print_success "================================================"
    print_success "Installation completed successfully!"
    print_success "================================================"
    echo ""
    print_info "System dependencies installed:"
    print_info "  ✓ openssl, jq, python3"
    echo ""
    print_info "Python packages installed:"
    print_info "  ✓ openpyxl (for XLSX support)"
    echo ""
    print_info "You can now use the user management system:"
    print_info "  sudo ./user.sh --add user --name <username>"
    print_info "  sudo ./user.sh --batch-add --file users.txt"
    print_info "  sudo ./user.sh --batch-add --file users.xlsx"
    echo ""
}

main "$@"