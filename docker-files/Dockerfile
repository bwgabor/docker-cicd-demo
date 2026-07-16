# File: docker-files/jenkins/Dockerfile
# Purpose: Custom Jenkins image with Docker CLI and Maven for local CI/CD demo
# Save to: docker-cicd-demo/docker-files/jenkins/Dockerfile
# Note: local demo environment only

FROM jenkins/jenkins:lts

USER root

# Alap csomagok és Docker repository kulcs
RUN apt-get update && apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  maven \
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y docker-ce-cli \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Docker socket használathoz szükséges csoport előkészítés
RUN groupadd -g 986 docker || true \
  && usermod -aG docker jenkins

# Setup entrypoint to align docker group GID at container startup
COPY entrypoint.sh /entrypoint.sh
USER root
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]