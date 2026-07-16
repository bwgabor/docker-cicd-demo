#!/bin/bash
# File: docker-files/jenkins/entrypoint.sh
# Purpose: Align docker group GID at container startup
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
groupmod -g "$DOCKER_GID" docker 2>/dev/null || groupadd -g "$DOCKER_GID" docker
usermod -aG docker jenkins
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh