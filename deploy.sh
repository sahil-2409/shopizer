#!/bin/bash
set -e

# Usage: ./deploy.sh [run-id]
# If no run-id provided, downloads from the latest CI run.

REPO="sahil-2409/shopizer"
ARTIFACT_PREFIX="shopizer-"
WORK_DIR="/tmp/shopizer-deploy"

rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"

# Download artifact from latest or specified run
if [ -n "$1" ]; then
  echo "⬇️  Downloading artifact from run $1..."
  gh run download "$1" -R "$REPO" -D "$WORK_DIR" -p "${ARTIFACT_PREFIX}*"
else
  echo "⬇️  Downloading artifact from latest run..."
  gh run download -R "$REPO" -D "$WORK_DIR" -p "${ARTIFACT_PREFIX}*"
fi

# Find the JAR
JAR=$(find "$WORK_DIR" -name "shopizer.jar" | head -1)
if [ -z "$JAR" ]; then
  echo "❌ shopizer.jar not found in artifact"
  exit 1
fi

# Ensure Colima is running
if ! colima status &>/dev/null; then
  echo "🚀 Starting Colima..."
  colima start
fi

# Build Docker image
echo "🐳 Building Docker image..."
BUILD_DIR="$WORK_DIR/build"
mkdir -p "$BUILD_DIR"
cp "$JAR" "$BUILD_DIR/"
cat <<EOF > "$BUILD_DIR/Dockerfile"
FROM adoptopenjdk/openjdk11-openj9:alpine
RUN mkdir /opt/app
COPY shopizer.jar /opt/app
CMD ["java", "-jar", "/opt/app/shopizer.jar"]
EOF
docker build -t shopizer:latest "$BUILD_DIR"

# Stop old container and run new one
echo "🔄 Deploying..."
docker stop shopizer 2>/dev/null && docker rm shopizer 2>/dev/null || true
docker run -d -p 8080:8080 --name shopizer shopizer:latest

# Health check
echo "🏥 Waiting for app to start..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8080/swagger-ui.html > /dev/null; then
    echo "✅ App is live at http://localhost:8080/swagger-ui.html"
    rm -rf "$WORK_DIR"
    exit 0
  fi
  sleep 5
done

echo "❌ Health check failed"
docker logs shopizer --tail 20
exit 1
