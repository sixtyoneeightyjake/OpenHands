# OpenHands Docker WebSocket Setup

This guide explains how to run OpenHands with WebSocket support using Docker, integrating the functionality from `start_openhands.sh` into a containerized environment.

## Overview

The Docker WebSocket setup provides:
- **WebSocket Support**: Real-time communication between frontend and backend
- **CORS Configuration**: Proper cross-origin resource sharing setup
- **Debug Mode**: Enhanced logging for troubleshooting
- **Containerized Environment**: Consistent deployment across different systems
- **Easy Management**: Simple start/stop commands

## Quick Start

### Prerequisites

- **Docker and Docker Compose installed**
  - **macOS**: Download Docker Desktop from https://www.docker.com/products/docker-desktop
  - **Linux**: Install using your package manager (e.g., `sudo apt install docker.io docker-compose`)
  - **Windows**: Download Docker Desktop from https://www.docker.com/products/docker-desktop
- At least 4GB of available RAM
- Port 3000 and 3001 available on your system

### Installing Docker (if not already installed)

**For macOS:**
```bash
# Install Docker Desktop
# 1. Download from https://www.docker.com/products/docker-desktop
# 2. Install the .dmg file
# 3. Start Docker Desktop from Applications
# 4. Verify installation:
docker --version
docker-compose --version
```

**For Linux (Ubuntu/Debian):**
```bash
# Update package index
sudo apt update

# Install Docker
sudo apt install docker.io docker-compose

# Add user to docker group (optional, to run without sudo)
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker-compose --version
```

### Running OpenHands

1. **Start the application:**
   ```bash
   ./start_openhands_docker.sh
   ```

2. **Access the application:**
   - **Local Access**: http://localhost:3000
   - **Backend API**: http://localhost:3000/api
   - **External Access**: http://[YOUR_IP]:3000 (requires additional configuration - see External Access section)

3. **Stop the application:**
   ```bash
   docker compose -f docker-compose.websocket.yml down
   ```

## Files Created

This setup creates several new files that work together:

### Core Files

- **`start_openhands_docker.sh`**: Main startup script that orchestrates the Docker setup
- **`docker-compose.websocket.yml`**: Docker Compose configuration for WebSocket setup
- **`containers/app/Dockerfile.websocket`**: Custom Dockerfile with WebSocket configuration
- **`containers/app/entrypoint-websocket.sh`**: Container entrypoint script with WebSocket support

### Configuration Files

- **`config.websocket.toml`**: Backend configuration template (already exists)
- **`frontend/.env.websocket`**: Frontend environment template (already exists)

## Configuration

### Environment Variables

The setup uses these key environment variables:

```bash
# Backend Configuration
BACKEND_HOST=0.0.0.0
BACKEND_PORT=3000

# Frontend Configuration
FRONTEND_HOST=0.0.0.0
FRONTEND_PORT=3001

# WebSocket Configuration
DEBUG=true
CORS_ALLOWED_ORIGINS="*"
RUNTIME=local
SERVE_FRONTEND=true

# Docker Configuration
WORKSPACE_BASE=./workspace
SANDBOX_USER_ID=$(id -u)
```

### Customization

You can customize the setup by:

1. **Modifying environment variables** in `start_openhands_docker.sh`
2. **Updating Docker Compose configuration** in `docker-compose.websocket.yml`
3. **Adjusting backend settings** in `config.websocket.toml`
4. **Changing frontend settings** in `frontend/.env.websocket`

## Architecture

### Container Structure

```
OpenHands Container
├── Backend (uvicorn server)
│   ├── WebSocket support
│   ├── CORS configuration
│   └── Debug logging
├── Frontend (built static files)
├── Workspace (mounted volume)
└── Configuration files
```

### Volume Mounts

- **`~/.openhands`**: Persistent application data
- **`./workspace`**: Project workspace (customizable)
- **`/var/run/docker.sock`**: Docker socket for container management

### Network Configuration

- **Port 3000**: Main application access
- **Port 3001**: Frontend development port (if needed)
- **Host networking**: Enabled for better connectivity

## Troubleshooting

### Common Issues

1. **Port conflicts:**
   ```bash
   # Check what's using the ports
   lsof -i :3000
   lsof -i :3001
   
   # Kill processes if needed
   pkill -f "uvicorn.*openhands"
   ```

2. **Container won't start:**
   ```bash
   # Check container logs
   docker compose -f docker-compose.websocket.yml logs
   
   # Rebuild the container
   docker compose -f docker-compose.websocket.yml up --build --force-recreate
   ```

3. **WebSocket connection issues:**
   ```bash
   # Check if CORS is properly configured
   curl -H "Origin: http://localhost:3001" \
        -H "Access-Control-Request-Method: GET" \
        -H "Access-Control-Request-Headers: X-Requested-With" \
        -X OPTIONS http://localhost:3000
   ```

### Debug Mode

The setup runs in debug mode by default. To view detailed logs:

```bash
# Follow container logs
docker compose -f docker-compose.websocket.yml logs -f

# View specific service logs
docker compose -f docker-compose.websocket.yml logs -f openhands
```

### Container Access

To access the running container for debugging:

```bash
# Access container shell
docker compose -f docker-compose.websocket.yml exec openhands /bin/bash

# Check running processes
docker compose -f docker-compose.websocket.yml exec openhands ps aux

# Check network connectivity
docker compose -f docker-compose.websocket.yml exec openhands netstat -tlnp
```

## Comparison with Original Setup

### Original `start_openhands.sh`
- Runs directly on host system
- Requires Python/Node.js installation
- Manual process management
- Host-dependent configuration

### Docker WebSocket Setup
- Runs in isolated container
- No host dependencies (except Docker)
- Automatic process management
- Consistent environment
- Easy cleanup and deployment

## External Access Configuration

By default, the Docker setup is configured for local access only. To enable external access via IP address or domain:

### Option 1: Host Network Mode (Simplest)

Modify `docker-compose.websocket.yml`:
```yaml
services:
  openhands:
    network_mode: host
    # Remove the ports section when using host networking
    # ports:
    #   - "3000:3000"
    #   - "3001:3001"
```

### Option 2: Bind to All Interfaces

Modify the ports section in `docker-compose.websocket.yml`:
```yaml
ports:
  - "0.0.0.0:3000:3000"  # Bind to all network interfaces
  - "0.0.0.0:3001:3001"
```

### Option 3: Reverse Proxy (Recommended for Production)

Use Nginx or Traefik for SSL termination and better security:

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # WebSocket support
    location /socket.io/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Firewall Configuration

Ensure your firewall allows connections on port 3000:

**Linux (ufw):**
```bash
sudo ufw allow 3000
```

**Linux (iptables):**
```bash
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
```

**macOS:**
```bash
# Check if firewall is enabled
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Add rule if needed (replace with your application path)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/docker
```

## Advanced Usage

### Custom Workspace

```bash
# Set custom workspace location
export WORKSPACE_BASE=/path/to/your/workspace
./start_openhands_docker.sh
```

### Development Mode

For development with live reloading:

```bash
# Enable development mode
export NODE_ENV=development
./start_openhands_docker.sh
```

### Production Deployment

For production use:

1. **Disable debug mode** in `docker-compose.websocket.yml`:
   ```yaml
   environment:
     - DEBUG=false
   ```

2. **Configure proper CORS origins**:
   ```yaml
   environment:
     - CORS_ALLOWED_ORIGINS=https://your-domain.com
   ```

3. **Set up reverse proxy** (nginx/traefik) - see External Access section

4. **Enable SSL/TLS termination**:
   ```yaml
   environment:
     - VITE_USE_TLS=true
   ```

5. **Use Docker secrets** for sensitive configuration

6. **Configure health checks and monitoring**

## Integration with Existing Workflow

This setup is designed to coexist with the existing OpenHands setup:

- Original files remain unchanged
- New files use `.websocket` suffix or separate directory
- Can switch between setups as needed
- Maintains compatibility with existing configurations

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review container logs for error messages
3. Ensure all prerequisites are met
4. Verify port availability
5. Check Docker and Docker Compose versions

For additional help, refer to the main OpenHands documentation or create an issue in the project repository.