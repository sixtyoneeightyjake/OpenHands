#!/bin/bash
set -eo pipefail

echo "🚀 Starting OpenHands with WebSocket configuration..."

# WebSocket specific configurations from start_openhands.sh
export DEBUG=true
export CORS_ALLOWED_ORIGINS="*"
export INSTALL_DOCKER=0
export RUNTIME=local
export BACKEND_HOST=${BACKEND_HOST:-0.0.0.0}
export BACKEND_PORT=${BACKEND_PORT:-3000}
export FRONTEND_HOST=${FRONTEND_HOST:-0.0.0.0}
export FRONTEND_PORT=${FRONTEND_PORT:-3001}
export SERVE_FRONTEND=true

echo "📋 WebSocket Configuration:"
echo "  Backend: ${BACKEND_HOST}:${BACKEND_PORT}"
echo "  Frontend: ${FRONTEND_HOST}:${FRONTEND_PORT}"
echo "  Runtime: ${RUNTIME}"
echo "  WebSocket: Enabled with CORS support"
echo "  Debug: ${DEBUG}"

# Original entrypoint.sh logic for user setup
if [[ $NO_SETUP == "true" ]]; then
  echo "Skipping setup, running as $(whoami)"
  "$@"
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "The OpenHands entrypoint.sh must run as root"
  exit 1
fi

if [ -z "$SANDBOX_USER_ID" ]; then
  echo "SANDBOX_USER_ID is not set"
  exit 1
fi

if [ -z "$WORKSPACE_MOUNT_PATH" ]; then
  # This is set to /opt/workspace in the Dockerfile. But if the user isn't mounting, we want to unset it so that OpenHands doesn't mount at all
  unset WORKSPACE_BASE
fi

if [[ "$INSTALL_THIRD_PARTY_RUNTIMES" == "true" ]]; then
  echo "Downloading and installing third_party_runtimes..."
  echo "Warning: Third-party runtimes are provided as-is, not actively supported and may be removed in future releases."

  if pip install 'openhands-ai[third_party_runtimes]' -qqq 2> >(tee /dev/stderr); then
    echo "third_party_runtimes installed successfully."
  else
    echo "Failed to install third_party_runtimes." >&2
    exit 1
  fi
fi

if [[ "$SANDBOX_USER_ID" -eq 0 ]]; then
  echo "Running OpenHands as root"
  export RUN_AS_OPENHANDS=false
  
  # Start the application with WebSocket configuration
  echo "🔧 Starting backend server with WebSocket support..."
  exec uvicorn openhands.server.listen:app \
    --host ${BACKEND_HOST} \
    --port ${BACKEND_PORT} \
    --reload \
    --reload-exclude "./workspace" \
    --log-level debug
else
  echo "Setting up enduser with id $SANDBOX_USER_ID"
  if id "enduser" &>/dev/null; then
    echo "User enduser already exists. Skipping creation."
  else
    if ! useradd -l -m -u $SANDBOX_USER_ID -s /bin/bash enduser; then
      echo "Failed to create user enduser with id $SANDBOX_USER_ID. Moving openhands user."
      incremented_id=$(($SANDBOX_USER_ID + 1))
      usermod -u $incremented_id openhands
      if ! useradd -l -m -u $SANDBOX_USER_ID -s /bin/bash enduser; then
        echo "Failed to create user enduser with id $SANDBOX_USER_ID for a second time. Exiting."
        exit 1
      fi
    fi
  fi
  usermod -aG app enduser
  # get the user group of /var/run/docker.sock and set enduser to that group
  DOCKER_SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
  echo "Docker socket group id: $DOCKER_SOCKET_GID"
  if getent group $DOCKER_SOCKET_GID; then
    echo "Group with id $DOCKER_SOCKET_GID already exists"
  else
    echo "Creating group with id $DOCKER_SOCKET_GID"
    groupadd -g $DOCKER_SOCKET_GID docker
  fi

  mkdir -p /home/enduser/.cache/huggingface/hub/

  usermod -aG $DOCKER_SOCKET_GID enduser
  echo "Running as enduser with WebSocket configuration"
  
  # Start the application with WebSocket configuration as enduser
  echo "🔧 Starting backend server with WebSocket support..."
  su enduser /bin/bash -c "uvicorn openhands.server.listen:app --host ${BACKEND_HOST} --port ${BACKEND_PORT} --reload --reload-exclude './workspace' --log-level debug"
fi