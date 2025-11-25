#!/usr/bin/env bash
# ================================================
# EC2 User Management System - Installation Script
# Version: 1.0.1
# ================================================
# Installs all components including example templates
# ================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
INSTALL_DIR="/opt/admin_dashboard"
SCRIPT_DIR="$INSTALL_DIR/scripts"
LIB_DIR="$SCRIPT_DIR/lib"
CONFIG_DIR="$INSTALL_DIR/config"
EXAMPLES_DIR="$SCRIPT_DIR/examples"
LOG_FILE="/var/log/user_mgmt_install.log"
$CONFIG_FILE="$CONFIG_DIR/user_mgmt.conf"
INSTALL_FLAG_FILE="$INSTALL_DIR/.install_complete"

# Print functions
print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system compatibility
check_system() {
    print_header "Checking System Compatibility"
    
    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_success "OS: $NAME $VERSION"
        log "OS: $NAME $VERSION"
    else
        print_warning "Could not detect OS version"
    fi
    
    # Check if directories already exist
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Installation directory already exists: $INSTALL_DIR"
        read -p "Overwrite existing installation? [y/N]: " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    echo ""
}

# Install dependencies
install_dependencies() {
    print_header "Installing Dependencies"
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        print_info "Using apt-get (Debian/Ubuntu)"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        print_info "Using yum (RHEL/Amazon Linux)"
    else
        print_error "No supported package manager found"
        exit 1
    fi
    
    # Update package list
    print_info "Updating package list..."
    sudo $PKG_MANAGER update -y &>/dev/null
    print_success "Package list updated"
    
    # Install jq (required for JSON operations)
    if ! command -v jq &> /dev/null; then
        print_info "Installing jq..."
        sudo $PKG_MANAGER install -y jq &>/dev/null
        print_success "jq installed"
        log "Installed jq"
    else
        print_success "jq already installed"
    fi
    
    # Check for basic utilities
    for cmd in awk sed grep cut; do
        if command -v $cmd &> /dev/null; then
            print_success "$cmd available"
        else
            print_warning "$cmd not found (may affect some features)"
        fi
    done
    
    echo ""
}

# Create directory structure
create_directories() {
    print_header "Creating Directory Structure"
    
    # Create main directories
    for dir in "$INSTALL_DIR" "$SCRIPT_DIR" "$LIB_DIR" "$CONFIG_DIR" "$EXAMPLES_DIR"; do
        if [ ! -d "$dir" ]; then
            sudo mkdir -p "$dir"
            print_success "Created: $dir"
            log "Created directory: $dir"
        else
            print_info "Exists: $dir"
        fi
    done
    
    # Set ownership
    sudo chown -R root:root "$INSTALL_DIR"
    print_success "Set ownership to root"
    
    # Create log directory
    sudo mkdir -p /var/log
    sudo touch /var/log/user_mgmt.log
    sudo chmod 640 /var/log/user_mgmt.log
    print_success "Created log file: /var/log/user_mgmt.log"
    
    # Create backup directory
    sudo mkdir -p /var/backups/users
    sudo chmod 700 /var/backups/users
    print_success "Created backup directory: /var/backups/users"
    
    echo ""
}

# Install configuration file
install_config() {
    print_header "Installing Configuration"
    
    local config_file="$CONFIG_DIR/user_mgmt.conf"
    
    if [ -f "$config_file" ]; then
        print_warning "Configuration file exists, creating backup..."
        sudo cp "$config_file" "$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Copy or create config (you would have the actual file here)
    print_info "Configuration file should be placed at: $config_file"
    print_info "Use the provided user_mgmt.conf template"
    
    echo ""
}

# Copy script files
install_scripts() {
    print_header "Installing Scripts"
    
    print_info "Script files should be copied to:"
    print_info "  Main script: $SCRIPT_DIR/user.sh"
    print_info "  Libraries:   $LIB_DIR/*.sh"
    
    # Make scripts executable
    if [ -f "$SCRIPT_DIR/user.sh" ]; then
        sudo chmod +x "$SCRIPT_DIR/user.sh"
        print_success "Made user.sh executable"
    fi
    
    if [ -d "$LIB_DIR" ]; then
        sudo chmod +x "$LIB_DIR"/*.sh 2>/dev/null || true
        print_success "Made library scripts executable"
    fi
    
    echo ""
}

# Install example templates
install_examples() {
    print_header "Installing Example Templates"
    
    print_info "Example templates should be placed in: $EXAMPLES_DIR"
    print_info "Templates to include:"
    print_info "  - users.json (bulk user creation)"
    print_info "  - roles.json (role-based provisioning)"
    print_info "  - groups.json (group management)"
    print_info "  - deletions.json (batch deletions)"
    print_info "  - README.md (documentation)"
    
    # Set permissions
    if [ -d "$EXAMPLES_DIR" ]; then
        sudo chmod 644 "$EXAMPLES_DIR"/*.json 2>/dev/null || true
        sudo chmod 644 "$EXAMPLES_DIR"/*.md 2>/dev/null || true
        print_success "Set example file permissions"
    fi
    
    echo ""
}

# Create symbolic link
create_symlink() {
    print_header "Creating System Command"
    
    if [ -f "$SCRIPT_DIR/user.sh" ]; then
        if [ -L /usr/local/bin/user-mgmt ]; then
            sudo rm /usr/local/bin/user-mgmt
        fi
        
        sudo ln -s "$SCRIPT_DIR/user.sh" /usr/local/bin/user-mgmt
        print_success "Created command: user-mgmt"
        print_info "You can now run: sudo user-mgmt [options]"
    else
        print_warning "user.sh not found, skipping symlink creation"
    fi
    
    echo ""
}

# Verify installation
verify_installation() {
    print_header "Verifying Installation"
    
    local errors=0
    
    # Check directories
    for dir in "$INSTALL_DIR" "$SCRIPT_DIR" "$LIB_DIR" "$CONFIG_DIR" "$EXAMPLES_DIR"; do
        if [ -d "$dir" ]; then
            print_success "Directory exists: $dir"
        else
            print_error "Missing directory: $dir"
            ((errors++))
        fi
    done
    
    # Check main script
    if [ -f "$SCRIPT_DIR/user.sh" ]; then
        print_success "Main script exists"
        if [ -x "$SCRIPT_DIR/user.sh" ]; then
            print_success "Main script is executable"
        else
            print_warning "Main script is not executable"
        fi
    else
        print_warning "Main script not found (needs to be copied)"
    fi
    
    # Check dependencies
    if command -v jq &> /dev/null; then
        print_success "jq is installed"
    else
        print_error "jq is not installed"
        ((errors++))
    fi
    
    # Check log file
    if [ -f /var/log/user_mgmt.log ]; then
        print_success "Log file exists"
    else
        print_error "Log file missing"
        ((errors++))
    fi
    
    echo ""
    
    if [ $errors -eq 0 ]; then
        print_success "Installation verification passed!"
    else
        print_warning "Installation verification found $errors issue(s)"
    fi
    
    echo ""
}

# Display next steps
show_next_steps() {
    print_header "Installation Complete!"
    
    echo ""
    echo "📁 Installation Directory: $INSTALL_DIR"
    echo "📝 Configuration: $CONFIG_DIR/user_mgmt.conf"
    echo "📄 Log File: /var/log/user_mgmt.log"
    echo "💾 Backups: /var/backups/users"
    echo "📚 Examples: $EXAMPLES_DIR"
    echo ""
    
    print_info "Next Steps:"
    echo ""
    echo "1. Copy script files to installation directory:"
    echo "   sudo cp user.sh $SCRIPT_DIR/"
    echo "   sudo cp lib/*.sh $LIB_DIR/"
    echo ""
    echo "2. Copy configuration file:"
    echo "   sudo cp user_mgmt.conf $CONFIG_DIR/"
    echo ""
    echo "3. Copy example templates:"
    echo "   sudo cp examples/*.json $EXAMPLES_DIR/"
    echo "   sudo cp examples/README.md $EXAMPLES_DIR/"
    echo ""
    echo "4. Make scripts executable:"
    echo "   sudo chmod +x $SCRIPT_DIR/user.sh"
    echo "   sudo chmod +x $LIB_DIR/*.sh"
    echo ""
    echo "5. Test installation:"
    echo "   sudo $SCRIPT_DIR/user.sh --version"
    echo "   sudo $SCRIPT_DIR/user.sh --help"
    echo ""
    echo "6. Try example operations:"
    echo "   sudo $SCRIPT_DIR/user.sh --view summary"
    echo "   sudo $SCRIPT_DIR/user.sh --view users"
    echo ""
    echo "7. Review example templates:"
    echo "   cat $EXAMPLES_DIR/README.md"
    echo "   cat $EXAMPLES_DIR/users.json"
    echo ""
    
    if [ -L /usr/local/bin/user-mgmt ]; then
        echo "💡 Quick command available: sudo user-mgmt --help"
        echo ""
    fi
    
    print_info "Documentation:"
    echo "  - Main help: sudo user-mgmt --help"
    echo "  - JSON examples: $EXAMPLES_DIR/README.md"
    echo "  - Configuration: $CONFIG_DIR/user_mgmt.conf"
    echo ""
    
    print_warning "Security Notes:"
    echo "  - Review and customize user_mgmt.conf"
    echo "  - Change DEFAULT_PASSWORD in config"
    echo "  - Restrict access to /opt/admin_dashboard"
    echo "  - Monitor /var/log/user_mgmt.log regularly"
    echo ""
}

# Main installation flow
main() {
    # Check if installation has already been completed.
    if [ -f "$INSTALL_FLAG_FILE" ]; then
        # Silently do nothing if the installation flag is found.
        return 0
    fi

    print_header "EC2 User Management System - Installer v1.0.1"
    echo ""
    
    # Initialize log
    sudo mkdir -p /var/log
    sudo touch "$LOG_FILE"
    sudo chmod 640 "$LOG_FILE"
    log "Installation started"
    
    # Run installation steps
    check_root
    check_system
    install_dependencies
    create_directories
    install_config
    install_scripts
    install_examples
    create_symlink
    verify_installation
    show_next_steps
    
    log "Installation completed"
    
    # Create a flag file to indicate that the installation is complete.
    sudo touch "$INSTALL_FLAG_FILE"
    log "Created installation flag at $INSTALL_FLAG_FILE"

    print_success "Installation script finished!"
}

# Run main function
main "$@"