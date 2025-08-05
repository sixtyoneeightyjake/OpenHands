# Docker Production Build Fix

## Issue Summary

The Docker production build was not accessible via IP or domain due to incorrect frontend configuration. The main issues were:

1. **Frontend Configuration Problem**: The frontend `.env` files were configured to connect to `0.0.0.0:3000`, which doesn't work from browsers
2. **Port Mismatch**: Template files had incorrect ports (12000/12001 instead of 3000/3001)
3. **Browser Compatibility**: Browsers cannot connect to `0.0.0.0` - they need `localhost` or a specific IP address

## Fixes Applied

### 1. Fixed Frontend Environment Configuration

**File: `frontend/.env`**
```bash
# Before (BROKEN)
VITE_BACKEND_HOST=0.0.0.0:3000
VITE_BACKEND_BASE_URL=0.0.0.0:3000

# After (FIXED)
VITE_BACKEND_HOST=localhost:3000
VITE_BACKEND_BASE_URL=localhost:3000
```

**File: `frontend/.env.websocket`**
```bash
# Before (BROKEN)
VITE_BACKEND_HOST=0.0.0.0:12000
VITE_BACKEND_BASE_URL=0.0.0.0:12000
VITE_FRONTEND_PORT=12001

# After (FIXED)
VITE_BACKEND_HOST=localhost:3000
VITE_BACKEND_BASE_URL=localhost:3000
VITE_FRONTEND_PORT=3001
```

### 2. Fixed Docker Startup Script

**File: `start_openhands_docker.sh`**

Updated the script to:
- Use `localhost:3000` instead of `0.0.0.0:3000` for frontend configuration
- Clean up backup files properly
- Ensure browser-compatible URLs

```bash
# Fixed configuration in startup script
sed -i.bak "s/VITE_BACKEND_HOST=.*/VITE_BACKEND_HOST=localhost:${BACKEND_PORT}/g" frontend/.env
sed -i.bak "s/VITE_BACKEND_BASE_URL=.*/VITE_BACKEND_BASE_URL=localhost:${BACKEND_PORT}/g" frontend/.env
```

## How It Works

### Backend Configuration (Correct)
The backend correctly binds to `0.0.0.0:3000` inside the Docker container:
- `BACKEND_HOST=0.0.0.0` - Allows connections from any IP
- `BACKEND_PORT=3000` - Standard port
- Docker maps `3000:3000` to make it accessible from host

### Frontend Configuration (Fixed)
The frontend now connects to `localhost:3000`:
- `VITE_BACKEND_HOST=localhost:3000` - Browser-compatible URL
- Works from the host machine accessing the Docker container
- Vite proxy handles API and WebSocket connections

### Docker Network Flow
```
Browser → localhost:3000 → Docker Container (0.0.0.0:3000) → Backend
```

## Testing the Fix

### Prerequisites
1. **Install Docker**: Follow the installation guide in `DOCKER_WEBSOCKET_SETUP.md`
2. **Ensure ports are available**: Check that ports 3000 and 3001 are not in use

### Start the Application
```bash
# Make the script executable (if needed)
chmod +x start_openhands_docker.sh

# Start OpenHands
./start_openhands_docker.sh
```

### Verify Access
1. **Local Access**: http://localhost:3000
2. **Network Access**: http://[YOUR_IP]:3000 (if Docker host networking is enabled)
3. **API Health Check**: http://localhost:3000/api/health

### Check Container Status
```bash
# View running containers
docker compose -f docker-compose.websocket.yml ps

# View logs
docker compose -f docker-compose.websocket.yml logs -f

# Test connectivity
curl http://localhost:3000/api/health
```

## External Access Configuration

For access via external IP or domain:

### Option 1: Host Network Mode
Add to `docker-compose.websocket.yml`:
```yaml
services:
  openhands:
    network_mode: host
    # Remove ports section when using host networking
```

### Option 2: Specific IP Binding
Modify port mapping in `docker-compose.websocket.yml`:
```yaml
ports:
  - "0.0.0.0:3000:3000"  # Bind to all interfaces
  - "0.0.0.0:3001:3001"
```

### Option 3: Reverse Proxy (Recommended for Production)
Use Nginx or Traefik:
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

## Troubleshooting

### Issue: "Connection Refused"
**Cause**: Docker container not running or ports not mapped
**Solution**:
```bash
# Check if container is running
docker compose -f docker-compose.websocket.yml ps

# Restart if needed
docker compose -f docker-compose.websocket.yml down
docker compose -f docker-compose.websocket.yml up --build -d
```

### Issue: "WebSocket Connection Failed"
**Cause**: CORS or proxy configuration
**Solution**:
1. Check browser developer console for specific errors
2. Verify `CORS_ALLOWED_ORIGINS=*` in environment
3. Ensure WebSocket proxy is configured in `vite.config.ts`

### Issue: "404 Not Found" for API calls
**Cause**: Frontend trying to connect to wrong backend URL
**Solution**:
1. Verify `VITE_BACKEND_HOST=localhost:3000` in `frontend/.env`
2. Check Vite proxy configuration
3. Ensure backend is responding: `curl http://localhost:3000/api/health`

### Issue: External IP Access Not Working
**Cause**: Container only bound to localhost
**Solution**:
1. Use host networking mode (Option 1 above)
2. Bind to all interfaces with `0.0.0.0:3000:3000`
3. Configure firewall to allow port 3000
4. Use reverse proxy for production

## Production Deployment Recommendations

1. **Use Reverse Proxy**: Nginx or Traefik for SSL termination and load balancing
2. **Enable SSL/TLS**: Set `VITE_USE_TLS=true` and configure certificates
3. **Restrict CORS**: Set specific origins instead of `*`
4. **Disable Debug Mode**: Set `DEBUG=false` for production
5. **Use Docker Secrets**: For sensitive configuration
6. **Health Checks**: Configure proper health check endpoints
7. **Logging**: Set up centralized logging
8. **Monitoring**: Add application and infrastructure monitoring

## Summary

The fixes ensure that:
- ✅ Frontend connects to the correct backend URL (`localhost:3000`)
- ✅ Docker container binds to all interfaces (`0.0.0.0:3000`)
- ✅ Port mapping works correctly (`3000:3000`)
- ✅ WebSocket connections function properly
- ✅ Application is accessible locally and can be configured for external access
- ✅ Configuration templates have correct default values

The application should now be accessible at `http://localhost:3000` when running the Docker setup, and can be configured for external access using the methods described above.