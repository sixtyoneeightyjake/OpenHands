#!/bin/bash

# OpenHands Docker WebSocket Configuration Startup Script
# This script integrates the start_openhands.sh functionality with Docker

set -e

echo "🚀 Starting OpenHands with Docker and WebSocket configuration..."

# Set environment variables for the runtime environment
export INSTALL_DOCKER=0
export RUNTIME=local
export BACKEND_HOST=0.0.0.0
export BACKEND_PORT=3000
export FRONTEND_HOST=0.0.0.0
export FRONTEND_PORT=3001
export SERVE_FRONTEND=true

# WebSocket specific configurations
export DEBUG=true
export CORS_ALLOWED_ORIGINS="*"

# Docker specific configurations
export WORKSPACE_BASE=${WORKSPACE_BASE:-$(pwd)/workspace}
export SANDBOX_USER_ID=${SANDBOX_USER_ID:-$(id -u)}
export DATE=$(date +%Y%m%d%H%M%S)

# Ensure the workspace directory exists
mkdir -p "${WORKSPACE_BASE}"

# Copy configuration templates if they don't exist
if [ ! -f config.toml ]; then
    echo "📋 Creating config.toml from WebSocket template..."
    cp config.websocket.toml config.toml
fi

if [ ! -f frontend/.env ]; then
    echo "📋 Creating frontend/.env from WebSocket template..."
    cp frontend/.env.websocket frontend/.env
    # Update the .env file with correct ports and localhost for browser access
    sed -i.bak "s/VITE_BACKEND_HOST=.*/VITE_BACKEND_HOST=localhost:${BACKEND_PORT}/g" frontend/.env
    sed -i.bak "s/VITE_BACKEND_BASE_URL=.*/VITE_BACKEND_BASE_URL=localhost:${BACKEND_PORT}/g" frontend/.env
    sed -i.bak "s/VITE_FRONTEND_PORT=.*/VITE_FRONTEND_PORT=${FRONTEND_PORT}/g" frontend/.env
    # Clean up backup file
    rm -f frontend/.env.bak
fi

echo "📋 Configuration:"
echo "  Backend: ${BACKEND_HOST}:${BACKEND_PORT}"
echo "  Frontend: ${FRONTEND_HOST}:${FRONTEND_PORT}"
echo "  Runtime: ${RUNTIME}"
echo "  WebSocket: Enabled with CORS support"
echo "  Workspace: ${WORKSPACE_BASE}"
echo "  User ID: ${SANDBOX_USER_ID}"

# Kill any existing containers
echo "🧹 Cleaning up existing containers..."
docker compose -f docker-compose.websocket.yml down --remove-orphans || true
sleep 2

# Build and start the container
echo "🔧 Building and starting OpenHands container with WebSocket support..."
docker compose -f docker-compose.websocket.yml up --build -d

# Wait for the container to be ready
echo "⏳ Waiting for OpenHands to start..."
timeout=60
while ! docker compose -f docker-compose.websocket.yml ps | grep -q "Up" && [ $timeout -gt 0 ]; do
    sleep 2
    timeout=$((timeout - 2))
done

if [ $timeout -eq 0 ]; then
    echo "❌ OpenHands failed to start within 60 seconds"
    echo "📊 Container logs:"
    docker compose -f docker-compose.websocket.yml logs
    exit 1
fi

# Wait for the backend to be responsive
echo "⏳ Waiting for backend to be ready..."
timeout=30
while ! nc -z localhost ${BACKEND_PORT} && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "❌ Backend failed to respond within 30 seconds"
    echo "📊 Container logs:"
    docker compose -f docker-compose.websocket.yml logs
    exit 1
fi

echo "✅ OpenHands is ready!"
echo ""
echo "🎉 OpenHands is now running in Docker!"
echo ""
echo "📡 Access URLs:"
echo "  Application: http://localhost:${BACKEND_PORT}"
echo "  Backend API: http://localhost:${BACKEND_PORT}/api"
echo ""
echo "🔌 WebSocket Configuration:"
echo "  - Socket.IO enabled with CORS support"
echo "  - Real-time communication between frontend and backend"
echo "  - Debug mode enabled for troubleshooting"
echo ""
echo "📝 To stop the application:"
echo "  docker compose -f docker-compose.websocket.yml down"
echo ""
echo "📊 To view logs:"
echo "  docker compose -f docker-compose.websocket.yml logs -f"
echo ""
echo "🔍 To access the container:"
echo "  docker compose -f docker-compose.websocket.yml exec openhands /bin/bash"

# Keep the script running and monitor the container
trap 'echo "🛑 Shutting down..."; docker compose -f docker-compose.websocket.yml down; exit 0' INT TERM

echo "📊 Monitoring container status (Ctrl+C to stop)..."
while docker compose -f docker-compose.websocket.yml ps | grep -q "Up"; do
    sleep 5
done

echo "❌ Container stopped unexpectedly"
echo "📊 Container logs:"
docker compose -f docker-compose.websocket.yml logs --tail=50
exit 1