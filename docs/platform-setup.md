# Platform Setup

## Purpose

This guide describes the manual configuration and validation steps required after the Docker CI/CD Demo platform has been provisioned. It covers host name resolution, Nginx Proxy Manager proxy hosts, Docker Registry validation, and the optional Portainer initialization.

The platform services are started by Vagrant provisioning and Docker Compose. This document focuses on the settings that are intentionally performed through service user interfaces or validated from the VM after the platform is running.


---


## Prerequisites

Before starting the environment, prepare the following on the host machine:

- [Vagrant](https://developer.hashicorp.com/vagrant/install) and [VirtualBox](https://www.virtualbox.org/wiki/Downloads) installed and available from the command line.
- Git, to clone the platform repository and track local documentation changes.
- At least 4 GB of RAM available for the virtual machine. More memory may be required when all platform services and the demo application are running.
- A web browser to access the platform user interfaces after provisioning.
- Permission to edit the host name resolution configuration on the host operating system. This is required to access the local service names used by the demo.

The Docker Engine and Docker Compose plugin are installed inside the Ubuntu VM by the provisioning script. They are not required on the host machine.

### Environment Configuration

Create the local environment file before starting the platform. Docker Compose uses this file to provide configuration values to multiple platform services.

```bash
cp .env.example .env
```

Review the values in `.env` before the first `vagrant up`. At minimum, set the initial Nginx Proxy Manager administrator credentials:

```dotenv
NPM_INITIAL_ADMIN_EMAIL=admin@example.local
NPM_INITIAL_ADMIN_PASSWORD=change-me
```

Do not commit `.env`. It may contain environment-specific configuration and credentials. Keep `.env.example` committed with safe placeholder values only.

> [!NOTE]
> This project is designed for a local, single-VM demonstration environment.
> It is not intended for production workloads or public Internet exposure.


---


## Host Name Resolution

The platform uses local host names instead of direct IP addresses. Add the following entries to the hosts file on the machine from which you access the platform:

```text
192.168.56.10 gitea.local
192.168.56.10 jenkins.local
192.168.56.10 portainer.local
192.168.56.10 npm.local
192.168.56.10 app.local
```

> [!NOTE]
> The current Registry workflow does not require `registry.local` to resolve on the host machine. Registry validation runs inside the VM through `localhost:5001`.
>
> Add `registry.local` to the host operating system hosts file only when you want to use the host machine Docker CLI with `registry.local:5001`.

On Windows, open the following file in a text editor with Administrator privileges:

```cmd
C:\Windows\System32\drivers\etc\hosts
```

On Linux and macOS, edit `/etc/hosts` with elevated privileges:

```bash
sudo nano /etc/hosts
```

After saving the file, verify that the host names resolve to the Vagrant VM:

```bash
ping gitea.local
ping jenkins.local
ping app.local
```

Each command should resolve the host name to `192.168.56.10`. A failed ICMP reply does not necessarily indicate a configuration problem; the important result is that the displayed IP address is `192.168.56.10`.

> [!IMPORTANT]
> Host name resolution only maps a name to the VM address. It does not create reverse-proxy routes, configure TLS, or publish a service. Configure the required Nginx Proxy Manager proxy hosts in the next section.


---


## Start and Verify the Platform

Run the following commands from the root directory of the platform repository:

```bash
vagrant up
```

The first startup creates the Ubuntu virtual machine and runs the provisioning script. Provisioning installs the required Docker components and starts the platform services with Docker Compose.

Check that Vagrant reports the VM as running:

```bash
vagrant status
```

Expected result:

```bash
default                   running
```

Connect to the VM:

```bash
vagrant ssh
```

Inside the VM, verify that the platform containers are running:

```bash
docker ps
```

The output should show five running platform containers:

- Gitea
- Jenkins
- Docker Registry
- Nginx Proxy Manager
- Portainer

Exit the VM when the check is complete:

```bash
exit
```

> [!TIP]
> If the VM already exists but the provisioning configuration has changed, run `vagrant provision` from the platform repository root. This reapplies the provisioning script without recreating the VM.


---


## Configure Nginx Proxy Manager

Nginx Proxy Manager provides HTTP reverse-proxy access to the platform web interfaces. The service listens on port `81` for administration and on ports `80` and `443` for proxied traffic.

### Initial Administrator Account

The platform `.env` file defines the initial Nginx Proxy Manager administrator credentials:

```dotenv
NPM_INITIAL_ADMIN_EMAIL=admin@example.local
NPM_INITIAL_ADMIN_PASSWORD=change-me
```

Docker Compose passes these values to the Nginx Proxy Manager container as `INITIAL_ADMIN_EMAIL` and `INITIAL_ADMIN_PASSWORD`. On the first startup with an empty Nginx Proxy Manager data volume, the container creates the initial administrator account automatically.

Open the administration interface in a browser:

```text
http://npm.local:81
```

Sign in with the credentials configured in the local `.env` file.

> [!IMPORTANT]
> The initial administrator environment variables are evaluated only when the Nginx Proxy Manager data volume is empty. Updating `.env` later does not change an existing administrator account or its password.

### Required Proxy Hosts

Open **Hosts** > **Proxy Hosts** and select **Add Proxy Host**. Create the following proxy hosts.

| Domain name       | Scheme | Forward hostname      | Forward port | Websockets support | Block Common Exploits |
| ----------------- | ------ | --------------------- | -----------: | ------------------ | --------------------- |
| `npm.local`       | `http` | `nginx-proxy-manager` |           81 | Enabled            | Enabled               |
| `gitea.local`     | `http` | `gitea`               |         3000 | Enabled            | Enabled               |
| `jenkins.local`   | `http` | `jenkins`             |         8080 | Enabled            | Enabled               |
| `app.local`       | `http` | `app`                 |           80 | Enabled            | Enabled               |
| `portainer.local` | `http` | `portainer`           |         9000 | Enabled            | Enabled               |

For every proxy host:

1. Enter the domain name, forwarding hostname, and forwarding port from the table.
2. Enable **Block Common Exploits**.
3. Leave caching disabled.
4. Do not request or configure an SSL certificate. This local demo environment does not use TLS.
5. Save the proxy host.

The forward hostnames are Docker service names, not the VM IP address. Nginx Proxy Manager and the target services communicate through the internal Docker network.

### Direct-access Services

Do not create a proxy host for the Docker Registry. The Registry is validated through its dedicated host port at `registry.local:5001`.

The Nginx Proxy Manager administration interface remains directly available at `http://npm.local:81`. A proxy host for the Nginx Proxy Manager UI is not required for this demo.

### Demo Application Proxy Host

Create the `app.local` proxy host after the Jenkins pipeline has deployed the demo application container. Its forward hostname and port must match the runtime container name and the container's internal HTTP port.

After the demo application is running, confirm its container details with:

```bash
docker ps
```

Then create a proxy host with `app.local` as the domain name. The exact upstream values are documented with the Jenkins and Gitea setup because the pipeline creates the application container.

### Verify Proxy Hosts

Open the following URLs in a browser:

```text
http://gitea.local
http://jenkins.local
http://portainer.local
http://npm.local
```

Each URL should load the corresponding platform user interface through Nginx Proxy Manager.


---


## Configure and Verify the Docker Registry

The local Docker Registry stores container images built by the Jenkins pipeline. The Registry container listens on port `5000` internally and is published on port `5001` of the Vagrant VM.

The Registry uses HTTP and Basic Authentication in this local demonstration environment. It is not exposed through Nginx Proxy Manager.

### Create the Authentication File

The Registry expects a bcrypt-based `htpasswd` file at the following host path:

```bash
config/registry/htpasswd
```

Docker Compose mounts this directory into the Registry container at `/auth`. The Registry reads the file as `/auth/htpasswd`.

Connect to the VM and open the synced platform repository directory:

```bash
vagrant ssh
cd /vagrant
```

The `config/registry` directory is part of the platform repository and is synchronized to the VM by Vagrant. Enter a Registry username and password when prompted:

```bash
read -rp "Registry username: " REGISTRY_USERNAME
read -rsp "Registry password: " REGISTRY_PASSWORD
printf '\n'
```

Generate the bcrypt-based authentication file:

```bash
docker run --rm --entrypoint htpasswd httpd:2 \
  -Bbn "$REGISTRY_USERNAME" "$REGISTRY_PASSWORD" \
  > config/registry/htpasswd

unset REGISTRY_USERNAME REGISTRY_PASSWORD
```

The command uses:

- `-B` to generate a bcrypt password hash;
- `-b` to read the password from the command arguments;
- `-n` to write the generated entry to standard output.

The resulting `config/registry/htpasswd` file contains a username and a password hash, not the plaintext password.

> [!IMPORTANT]
> Do not commit `config/registry/htpasswd` to the platform repository. Ensure that the file is ignored by Git and store the selected credentials securely. The same credentials are required later when configuring the Jenkins Registry credential.

### Restart the Registry

The Registry container is already created and running as part of the platform startup. Restart it after the authentication file has been generated so that it loads the new `htpasswd` file:

```bash
docker restart registry
```

Check that the Registry container is running:

```bash
docker compose ps registry
```

The Registry service should report an `Up` status.

### Verify Registry Authentication

The Docker daemon is configured by the provisioning script to allow the local HTTP Registry aliases:

```text
registry.local
registry:5001
localhost:5001
```

Log in to the Registry from inside the VM:

```bash
docker login localhost:5001
```

Enter the Registry username and password used to generate the `htpasswd` file. A successful login returns:

```text
Login Succeeded
```

### Push and Pull a Test Image

Pull a minimal public image:

```bash
docker pull hello-world:latest
```

Tag it for the local Registry:

```bash
docker tag hello-world:latest localhost:5001/registry-smoke-test:latest
```

Push the tagged image:

```bash
docker push localhost:5001/registry-smoke-test:latest
```

Remove the local Registry tag, then pull it again from the Registry:

```bash
docker image rm localhost:5001/registry-smoke-test:latest
docker pull localhost:5001/registry-smoke-test:latest
```

The final pull confirms that the image was successfully stored in and retrieved from the private Registry.

Exit the VM when the validation is complete:

```bash
exit
```

> [!WARNING]
> HTTP transport and Docker insecure Registry configuration are acceptable only for this isolated local demonstration environment. Do not use this configuration for a production or Internet-exposed Registry.


---


## Optional: Initialize Portainer

Portainer is an optional web interface for inspecting and managing the Docker resources of the Vagrant VM. It is not required for the Jenkins pipeline or the demo application deployment.

Nginx Proxy Manager publishes the Portainer interface at:

```text
http://portainer.local
```

### Create the Administrator Account

Open `http://portainer.local` in a browser.

On the initial setup screen:

1. Create a Portainer administrator username and password.
2. Store the password securely.
3. Continue with the initial setup wizard.

Portainer detects the local Docker environment because the platform Compose configuration mounts the VM Docker socket into the Portainer container:

```text
/var/run/docker.sock -> /var/run/docker.sock
```

Complete the wizard to access the local Docker environment.

### Verify the Local Environment

After initialization, open the `local` environment in Portainer.

Verify that the following platform containers are visible:

- Gitea
- Jenkins
- Docker Registry
- Nginx Proxy Manager
- Portainer

Use Portainer for optional inspection of containers, images, volumes, networks, and container logs. The platform configuration remains managed by Vagrant, Docker Compose, and the platform repository files.

> [!WARNING]
> Access to the Docker socket gives Portainer administrative control over the VM Docker daemon. Do not expose this Portainer instance to untrusted networks or use it as a production management endpoint.

## Troubleshooting

### Host Names Do Not Resolve

If `gitea.local`, `jenkins.local`, or another platform host name does not resolve:

1. Verify that the relevant entry exists in the host operating system hosts file.
2. Verify that every platform host name maps to `192.168.56.10`.
3. Confirm that the Vagrant VM is running:

   ```bash
   vagrant status
   ```

4. Test the resolution:

   ```bash
   ping gitea.local
   ```

The displayed IP address should be `192.168.56.10`. An ICMP timeout alone does not prove that the hosts entry is incorrect.

### Vagrant VM or Containers Are Not Running

Check the VM state from the platform repository root:

```bash
vagrant status
```

Start the VM when necessary:

```bash
vagrant up
```

Check the platform containers from inside the VM:

```bash
vagrant ssh
docker ps
```

If the provisioning script was changed after the VM was created, reapply it:

```bash
exit
vagrant provision
```

### Nginx Proxy Manager Returns 502 Bad Gateway

A `502 Bad Gateway` response usually means that Nginx Proxy Manager cannot reach its configured upstream service.

1. Confirm that the target container is running:

   ```bash
   vagrant ssh -c 'docker ps'
   ```

2. In Nginx Proxy Manager, verify the proxy host forward hostname and port.
3. Use Docker service names as forward hostnames, such as `gitea`, `jenkins`, or `portainer`; do not use the VM IP address.
4. Confirm that the target service uses the expected internal port.

### Nginx Proxy Manager Initial Credentials Do Not Apply

The `NPM_INITIAL_ADMIN_EMAIL` and `NPM_INITIAL_ADMIN_PASSWORD` values are used only when the Nginx Proxy Manager data volume is empty.

If an administrator account already exists, changing these values in `.env` does not change the existing account or its password. Use the existing account to sign in. Recreating the Nginx Proxy Manager data volume removes its saved configuration and should only be performed intentionally.

### Registry Returns 401 Unauthorized

An HTTP `401 Unauthorized` response from the following endpoint is expected:

```bash
curl -i http://127.0.0.1:5001/v2/
```

The response confirms that the Registry is reachable and that Basic Authentication is enabled. Use `docker login localhost:5001` to authenticate before pushing or pulling private images.

### Docker Login to the Registry Fails

First, verify that the Registry container is running and that the Docker daemon accepts the local insecure Registry aliases:

```bash
vagrant ssh
cd /vagrant
docker compose ps registry
docker info | sed -n '/Insecure Registries:/,/Live Restore Enabled:/p'
```

The insecure Registry configuration should include:

```text
registry.local
registry:5001
localhost:5001
```

If one or more aliases are missing, exit the VM and reapply provisioning:

```bash
exit
vagrant provision
```

Then retry the login:

```bash
vagrant ssh -c 'docker login localhost:5001'
```

### Registry Authentication File Is Missing or Invalid

Check that the `htpasswd` file exists in the synchronized repository path:

```bash
vagrant ssh -c 'ls -l /vagrant/config/registry/htpasswd'
```

If the file is missing, regenerate it as described in the Registry setup section. If the file was updated, restart the Registry container:

```bash
vagrant ssh -c 'docker restart registry'
```

Inspect Registry logs when the problem persists:

```bash
vagrant ssh -c 'docker logs registry'
```

### Portainer Does Not Show the Local Environment

Portainer requires access to the VM Docker socket. Verify that the socket is mounted into the Portainer container:

```bash
vagrant ssh -c 'docker inspect --format "{{range .Mounts}}{{println .Source \"->\" .Destination}}{{end}}" portainer'
```

The output must include:

```text
/var/run/docker.sock -> /var/run/docker.sock
```

If the mount is present but the Portainer UI still does not show the `local` environment, verify the Portainer container logs:

```bash
vagrant ssh -c 'docker logs portainer'
```
