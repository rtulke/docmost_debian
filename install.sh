# Direct installation - copy and paste this entire block
cat > /tmp/docmost-install.sh << 'SCRIPT_END'
#!/bin/bash
#
# Docmost Installation Script for Debian 12
# Author: Auto-generated installer
# Usage: curl -sSL https://github.com/rtulke/docmost_debian/install.sh | bash
#

set -euo pipefail

# Configuration defaults
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/docmost-install.log"
readonly INSTALL_DIR_DEFAULT="/opt/docmost"
readonly DOCKER_PORT_DEFAULT="3000"
readonly DOMAIN_DEFAULT="localhost"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
INSTALL_DIR=""
DOCKER_PORT=""
DOMAIN=""
APP_URL=""
APP_SECRET=""
POSTGRES_PASSWORD=""
USE_SUDO=""

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Output functions
info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    exit 1
}

# Check if running as root or with sudo capabilities
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        USE_SUDO=""
        info "Running as root"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        USE_SUDO="sudo"
        info "Running with sudo privileges"
    else
        error "This script requires root privileges or sudo access"
    fi
}

# Generate secure passwords and secrets
generate_secrets() {
    if command -v openssl >/dev/null 2>&1; then
        APP_SECRET=$(openssl rand -hex 32)
        POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    else
        # Fallback if openssl not available
        APP_SECRET=$(head -c 32 /dev/urandom | xxd -p)
        POSTGRES_PASSWORD=$(head -c 25 /dev/urandom | base64 | tr -d "=+/")
    fi
    
    info "Generated secure secrets"
}

# Interactive configuration
get_user_input() {
    echo
    info "Docmost Installation Configuration"
    echo "=================================="
    echo
    
    # Install directory
    read -p "Installation directory [$INSTALL_DIR_DEFAULT]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-$INSTALL_DIR_DEFAULT}
    
    # Docker port
    read -p "Docker container port [$DOCKER_PORT_DEFAULT]: " DOCKER_PORT
    DOCKER_PORT=${DOCKER_PORT:-$DOCKER_PORT_DEFAULT}
    
    # Domain or IP
    read -p "Domain or IP address [$DOMAIN_DEFAULT]: " DOMAIN
    DOMAIN=${DOMAIN:-$DOMAIN_DEFAULT}
    
    # APP_URL
    if [[ "$DOMAIN" == "localhost" || "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        APP_URL="http://${DOMAIN}"
    else
        read -p "Use HTTPS? (y/N): " use_https
        if [[ "${use_https,,}" =~ ^y(es)?$ ]]; then
            APP_URL="https://${DOMAIN}"
        else
            APP_URL="http://${DOMAIN}"
        fi
    fi
    
    # Port in URL if not standard
    if [[ "$DOCKER_PORT" != "80" && "$DOCKER_PORT" != "443" && "$DOMAIN" == "localhost" ]]; then
        APP_URL="${APP_URL}:${DOCKER_PORT}"
    fi
    
    echo
    info "Configuration summary:"
    echo "  Install directory: $INSTALL_DIR"
    echo "  Docker port: $DOCKER_PORT"
    echo "  Domain: $DOMAIN"
    echo "  APP_URL: $APP_URL"
    echo
    
    read -p "Continue with installation? (y/N): " confirm
    if [[ ! "${confirm,,}" =~ ^y(es)?$ ]]; then
        error "Installation cancelled by user"
    fi
}

# Update system packages
update_system() {
    info "Updating system packages..."
    $USE_SUDO apt update -qq
    $USE_SUDO apt install -y ca-certificates curl gnupg lsb-release git nginx
    success "System packages updated"
}

# Install Docker
install_docker() {
    info "Installing Docker..."
    
    # Remove old versions
    $USE_SUDO apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    $USE_SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | $USE_SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    $USE_SUDO chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        $USE_SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    $USE_SUDO apt update -qq
    $USE_SUDO apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group if not root
    if [[ -n "$USE_SUDO" ]]; then
        $USE_SUDO usermod -aG docker "$USER"
        warning "User added to docker group. You may need to logout and login again."
    fi
    
    # Start and enable Docker
    $USE_SUDO systemctl start docker
    $USE_SUDO systemctl enable docker
    
    success "Docker installed successfully"
}

# Install PostgreSQL
install_postgresql() {
    info "Installing PostgreSQL..."
    $USE_SUDO apt install -y postgresql postgresql-contrib
    $USE_SUDO systemctl start postgresql
    $USE_SUDO systemctl enable postgresql
    success "PostgreSQL installed successfully"
}

# Create installation directory and setup docker-compose
setup_docmost() {
    info "Setting up Docmost..."
    
    # Create directory
    $USE_SUDO mkdir -p "$INSTALL_DIR"
    $USE_SUDO chown "$USER:$USER" "$INSTALL_DIR" 2>/dev/null || true
    cd "$INSTALL_DIR"
    
    # Create docker-compose.yml
    cat > docker-compose.yml << EOF
version: "3.8"

services:
  docmost:
    image: docmost/docmost:latest
    depends_on:
      - db
      - redis
    environment:
      APP_URL: "${APP_URL}"
      APP_SECRET: "${APP_SECRET}"
      DATABASE_URL: "postgresql://docmost:${POSTGRES_PASSWORD}@db:5432/docmost?schema=public"
      REDIS_URL: "redis://redis:6379"
    ports:
      - "${DOCKER_PORT}:3000"
    restart: unless-stopped
    volumes:
      - docmost:/app/data/storage

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: docmost
      POSTGRES_USER: docmost
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD}"
    restart: unless-stopped
    volumes:
      - db_data:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"

  redis:
    image: redis:7.2-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data

volumes:
  docmost:
  db_data:
  redis_data:
EOF
    
    success "Docker Compose configuration created"
}

# Configure nginx
configure_nginx() {
    info "Configuring nginx..."
    
    # Create nginx configuration
    cat > /tmp/docmost.conf << EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${DOCKER_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Health check endpoint
    location /api/health {
        proxy_pass http://127.0.0.1:${DOCKER_PORT}/api/health;
        access_log off;
    }
}
EOF
    
    $USE_SUDO mv /tmp/docmost.conf /etc/nginx/sites-available/docmost
    $USE_SUDO ln -sf /etc/nginx/sites-available/docmost /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    if $USE_SUDO nginx -t; then
        $USE_SUDO systemctl restart nginx
        $USE_SUDO systemctl enable nginx
        success "Nginx configured successfully"
    else
        error "Nginx configuration test failed"
    fi
}

# Start Docmost services
start_services() {
    info "Starting Docmost services..."
    cd "$INSTALL_DIR"
    
    # Pull images and start services
    docker compose pull
    docker compose up -d
    
    # Wait for services to be ready
    info "Waiting for services to start..."
    sleep 10
    
    # Check if services are running
    if docker compose ps | grep -q "Up"; then
        success "Docmost services started successfully"
    else
        error "Failed to start Docmost services"
    fi
}

# Create configuration summary
create_summary() {
    local summary_file="${INSTALL_DIR}/INSTALLATION_SUMMARY.md"
    
    cat > "$summary_file" << EOF
# Docmost Installation Summary

## Installation Details
- **Installation Date**: $(date)
- **Installation Directory**: $INSTALL_DIR
- **Docker Port**: $DOCKER_PORT
- **Domain**: $DOMAIN
- **APP_URL**: $APP_URL

## Access Information
- **Web Interface**: $APP_URL
- **Health Check**: ${APP_URL}/api/health

## Generated Credentials
- **App Secret**: $APP_SECRET
- **Database Password**: $POSTGRES_PASSWORD

## Useful Commands

### Docker Management
\`\`\`bash
cd $INSTALL_DIR

# View logs
docker compose logs -f

# Stop services
docker compose down

# Start services
docker compose up -d

# Update Docmost
docker pull docmost/docmost:latest
docker compose up --force-recreate --build docmost -d
\`\`\`

### Service Status
\`\`\`bash
# Check Docker services
docker compose ps

# Check nginx status
sudo systemctl status nginx

# Check PostgreSQL status
sudo systemctl status postgresql
\`\`\`

## Configuration Files
- Docker Compose: $INSTALL_DIR/docker-compose.yml
- Nginx Config: /etc/nginx/sites-available/docmost
- Installation Log: $LOG_FILE

## Next Steps
1. Open your web browser and navigate to: $APP_URL
2. Complete the Docmost setup wizard
3. Create your workspace and admin account

## Support
If you encounter issues, check the logs or visit:
- GitHub: https://github.com/docmost/docmost
- Documentation: https://docmost.com/docs
EOF
    
    success "Installation summary created: $summary_file"
}

# Main installation function
main() {
    info "Starting Docmost installation for Debian 12..."
    
    check_privileges
    generate_secrets
    get_user_input
    
    update_system
    install_docker
    install_postgresql
    setup_docmost
    configure_nginx
    start_services
    create_summary
    
    echo
    success "Docmost installation completed successfully!"
    echo
    info "Access your Docmost instance at: $APP_URL"
    info "Installation summary: ${INSTALL_DIR}/INSTALLATION_SUMMARY.md"
    echo
    warning "If running as non-root user, you may need to logout and login again to use Docker commands."
}

# Run main function
main "$@"
SCRIPT_END

chmod +x /tmp/docmost-install.sh
/tmp/docmost-install.sh
