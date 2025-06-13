# Docmost Debian 12 Installer

Automated installation script for [Docmost](https://docmost.com/) on Debian 12, featuring automatic secret generation, nginx configuration, and PostgreSQL setup.

## Features

- **One-command installation** via curl
- **Automatic secret generation** for security
- **Nginx reverse proxy** configuration with WebSocket support
- **Docker** and Docker Compose setup
- **Interactive configuration** with sensible defaults
- **Root and sudo user** support
- **Comprehensive logging** and error handling

## Security Features

- Secure random secret generation using OpenSSL
- Nginx security headers and WebSocket support
- Proper file permissions and ownership

## Requirements

- **Debian 12** (Bookworm)
- **Root access** or sudo privileges
- **Internet connection** for package downloads
- **Minimum 2GB RAM** recommended
- **Minimum 10GB disk space** recommended

## Quick Installation

This script can be executed as root user or as normal user if you do not want to run the containers under root.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/rtulke/docmost_debian/main/install.sh)
```
*You can not run this script by using `curl -sSL https://raw.githubusercontent.com/rtulke/docmost_debian/main/install.sh | bash` because of bash substituions.*

## Manual Installation

1. Download the script:
   ```bash
   wget https://raw.githubusercontent.com/rtulke/docmost_debian/main/install.sh
   chmod +x install.sh
   ```

2. Run the installer:
   ```bash
   ./install.sh
   ```

## What Gets Installed

- **Docker CE** with Docker Compose plugin
- **Nginx** with reverse proxy configuration
- **Redis** (via Docker container)
- **Docmost** application (latest version)

## Configuration Options

During installation, you'll be prompted for:

- **Installation directory** (default: `/opt/docmost`)
- **Docker container port** (default: `3000`)
- **Domain or IP address** (default: `localhost`)
- **HTTPS preference** (for custom domains)

## Generated Secrets

The script automatically generates:
- **APP_SECRET**: 64-character hexadecimal secret
- **POSTGRES_PASSWORD**: 25-character secure database password

## Post-Installation

After successful installation:

1. Navigate to your configured URL (e.g., `http://your-domain.com` or `http://<ip>`)
2. Complete the Docmost setup wizard
3. Create your workspace and admin account

## Service Management

### Docker Services
```bash
cd /opt/docmost  # or your chosen directory

# View logs
docker compose logs -f

# Stop services
docker compose down

# Start services
docker compose up -d

# Update Docmost
docker pull docmost/docmost:latest
docker compose up --force-recreate --build docmost -d
```

### System Services
```bash
# Nginx status
sudo systemctl status nginx

# Docker status
sudo systemctl status docker
```

## File Locations

- **Docker Compose**: `/opt/docmost/docker-compose.yml`
- **Nginx Config**: `/etc/nginx/sites-available/docmost`
- **Installation Log**: `/tmp/docmost-install.log`
- **Installation Summary**: `/opt/docmost/INSTALLATION_SUMMARY.md`



## Troubleshooting

### Common Issues

1. **Docker permission denied**:
   ```bash
   sudo usermod -aG docker $USER
   # Logout and login again
   ```

2. **Nginx configuration test failed**:
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. **Services not starting**:
   ```bash
   cd /opt/docmost
   docker compose logs
   ```

4. **Nginx is not working**:
   ```bash
   curl http://localhost:3000
   ```   

### Logs and Debugging

- Installation log: `/tmp/docmost-install.log`
- Docker logs: `docker compose logs -f`
- Nginx logs: `/var/log/nginx/error.log`
- System logs: `journalctl -u docker -f`

## Updating Docmost

To update to the latest version:

```bash
cd /opt/docmost
docker pull docmost/docmost:latest
docker compose up --force-recreate --build docmost -d
```

## Uninstallation

To remove Docmost:

```bash
cd /opt/docmost
docker compose down -v
sudo rm -rf /opt/docmost
sudo rm /etc/nginx/sites-enabled/docmost
sudo rm /etc/nginx/sites-available/docmost
sudo systemctl reload nginx
```

## Contributing

Feel free to open issues or submit pull requests for improvements.

## License

This installer script is provided as-is under the MIT License.

## Support

- [Docmost Documentation](https://docmost.com/docs)
- [Docmost GitHub Repository](https://github.com/docmost/docmost)
- [Docker Installation Guide](https://docs.docker.com/engine/install/debian/)

---

**Note**: This installer is specifically designed for Debian 12. For other distributions, please refer to the official Docmost documentation.
