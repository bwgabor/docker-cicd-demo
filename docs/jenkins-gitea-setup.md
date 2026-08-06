# Jenkins and Gitea Setup

## Purpose

This guide configures the integration between Gitea and Jenkins in the local Docker CI/CD demo environment.

After completing the steps, a push to the `main` branch of the demo application repository triggers the Jenkins pipeline automatically through the Generic Webhook Trigger plugin.


---


## Prerequisites

Complete [Platform Setup](platform-setup.md) before starting this guide. This guide uses two different network contexts:

- **Host machine:** The computer running Vagrant and the web browser. Local domains such as `gitea.local` and `jenkins.local` resolve to the Vagrant VM IP address through the host machine's `/etc/hosts` file.
- **Docker network inside the VM:** Containers communicate through Docker Compose service names, such as `gitea` and `jenkins`. These names are not resolved by the host machine.

Before starting, make sure that the following requirements are met:

- The Vagrant virtual machine is running and the Docker Compose stack is healthy.
- The host machine has hosts file entries [(see Platform Setup)](platform-setup.md) that map `gitea.local` and `jenkins.local` to the Vagrant VM IP address.
- The `gitea.local` and `jenkins.local` proxy hosts are configured in Nginx Proxy Manager [(see Platform Setup)](platform-setup.md).
- You can reach the Gitea UI at `http://gitea.local` and the Jenkins UI at `http://jenkins.local`.
  > [!NOTE]
  > Gitea's configured `ROOT_URL` includes port `3000`, so clone URLs shown in the Gitea UI appear as `http://gitea.local:3000/…`. The reverse-proxied UI at `http://gitea.local` and the container-network URL `http://gitea:3000` used by Jenkins are both correct in their own context.

This guide creates the Gitea administrator account and the demo application repository in section 1. It uses the following names throughout:

| Item                            | Value                |
| ------------------------------- | -------------------- |
| Gitea administrator account     | `giteaadmin`         |
| Demo application repository     | `nginx-static-site`  |
| Default branch                  | `main`               |

> [!IMPORTANT]
> The `Jenkinsfile` in the demo application repository contains a hard-coded checkout URL, `http://gitea:3000/giteaadmin/nginx-static-site.git`. If you choose a different account or repository name, update the `Jenkinsfile` and the Jenkins job **Repository URL** to match.


---


## 1. Complete the Gitea Setup

### Run the first-run installation

1. On the host machine, open `http://gitea.local` in a web browser.

   On first access, Gitea displays its installation page.

2. Leave the database and server settings unchanged.

   Docker Compose supplies these values as `GITEA__*` environment variables, including the SQLite3 database type and the server domain. Values entered in the installation form are overwritten by the environment variables when the container restarts.

3. Expand **Administrator Account Settings** and create the administrator account:

   | Field                  | Value                     |
   | ---------------------- | ------------------------- |
   | Administrator username | `giteaadmin`              |
   | Password               | A password of your choice |
   | Email address          | An address of your choice |

   Store the password in a password manager.

4. Select **Install Gitea** and wait for the installation to complete.

5. Sign in as `giteaadmin` and confirm that the Gitea dashboard opens.

> [!NOTE]
> The account name `giteaadmin` is used by the `Jenkinsfile` checkout URL, the Jenkins job **Repository URL**, and the webhook path in the remaining sections of this guide.

### Create the demo application repository

1. Select **+** → **New Repository**.

2. Configure the repository:

   | Field           | Value               |
   | --------------- | ------------------- |
   | Owner           | `giteaadmin`        |
   | Repository name | `nginx-static-site` |
   | Visibility      | `Private`           |
   | Default branch  | `main`              |

3. Leave the repository empty. Do not initialize it with a README, `.gitignore`, or license file.

4. Select **Create Repository**.

The demo application files are pushed into this repository in [section 8](#8-verify-the-integration), after Jenkins and the webhook are configured.

> [!NOTE]
> The repository is private so that the Jenkins Git credential is actually exercised. A public repository would let the pipeline check out without authentication and would hide credential errors.


---


## 2. Unlock Jenkins and Complete the Setup Wizard

### Unlock Jenkins

1. Connect to the Vagrant VM:

   ```bash
   vagrant ssh
   cd /vagrant
   ```

2. Confirm that the Jenkins container is running:

   ```bash
   docker compose ps jenkins
   ```

3. Print the initial administrator password:

   ```bash
   docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```

4. On the host machine, open `http://jenkins.local` in a web browser.

5. Paste the password into the **Administrator password** field and select **Continue**.

> The initial administrator password is generated only during the first Jenkins startup. Store the administrator credentials in a password manager after completing the setup wizard.

### Complete the setup wizard

1. On the **Customize Jenkins** page, select **Install suggested plugins**.

2. Wait for the plugin installation to complete.

3. On the **Create First Admin User** page, create a dedicated administrator account.

   Store the credentials in a password manager. Do not use the initial unlock password as a permanent credential.

4. On the **Instance Configuration** page, set the Jenkins URL to:

   ```text
   http://jenkins.local/
   ```

5. Select **Save and Finish**, then select **Start using Jenkins**.

6. Confirm that the Jenkins dashboard opens at `http://jenkins.local`.

> The Jenkins URL must use the host-facing domain, `jenkins.local`. Do not use the Docker Compose service name `jenkins` here: it is only resolvable by containers on the Docker network inside the Vagrant VM.


---


## 3. Install Required Plugins

The setup wizard installs the standard Jenkins plugin set. Install the following additional plugins before creating the pipeline job:

1. Select **Manage Jenkins** → **Plugins**.

2. Open the **Available plugins** tab.

3. Search for and install:

   ```text
   Gitea
   Generic Webhook Trigger
   ```

4. Select **Install** and restart Jenkins if Jenkins requests it.

5. Confirm that both plugins are listed on the **Installed plugins** tab.

The following plugins must be available before continuing:

| Plugin                  | Purpose                                                                                 |
| ----------------------- | --------------------------------------------------------------------------------------- |
| Pipeline                | Runs the `Jenkinsfile` pipeline                                                         |
| Git                     | Clones the demo application repository                                                  |
| Credentials             | Stores access credentials securely                                                      |
| Gitea                   | Adds the Gitea server integration and the `Gitea Personal Access Token` credential type |
| Generic Webhook Trigger | Starts the pipeline from a Gitea push webhook                                           |

> The Gitea plugin provides the Gitea server configuration and the Gitea Personal Access Token credential type. It does not trigger this pipeline.


---


## 4. Configure Gitea Credentials

### Create a Gitea personal access token

1. On the host machine, sign in to Gitea at `http://gitea.local`.

2. Open **User Settings** → **Applications**.

3. In the **Manage Access Tokens** section, enter a descriptive token name, for example:

   ```text
   jenkins-integration
   ```
4. Select the required token scopes (read access to repository and organization is sufficient for this demo).

5. Select **Generate Token**.

6. Copy the token immediately and store it in a password manager. Gitea does not display the token value again.

### Add the token to Jenkins

1. In Jenkins, select **Manage Jenkins** → **Credentials**.

2. Open the global credential store:

   ```text
   System → Global credentials (unrestricted)
   ```

3. Select **Add Credentials**.

4. Configure the credential with the following values:

   | Field       | Value                                |
   | ----------- | ------------------------------------ |
   | Kind        | `Gitea Personal Access Token`        |
   | Scope       | `Global`                             |
   | Token       | The token generated in Gitea         |
   | ID          | `gitea-api-token`                    |
   | Description | `Gitea API access token for Jenkins` |

5. Select **Create**.

### Add the Registry credential

| Field | Value                                                                                     |
| ----- | ----------------------------------------------------------------------------------------- |
| Kind  | `Username with password`                                                                  |
| ID    | `registry-creds` , using the username and password generated for config/registry/htpasswd |

> [!NOTE]
> Note that the ID must match REGISTRY_CRED in the Jenkinsfile.

### Configure the Gitea server connection

1. Select **Manage Jenkins** → **System**.

2. Find the **Gitea Servers** section and select **Add** → **Gitea Server**.

3. Configure the server connection:

   | Field       | Value               |
   | ----------- | ------------------- |
   | Name        | `local-gitea`       |
   | Gitea URL   | `http://gitea:3000` |

> Jenkins runs in a Docker container inside the Vagrant VM. The `gitea` hostname is the Docker Compose service name and is resolved only on the Docker network. Do not use `gitea.local` for the Jenkins-to-Gitea connection: that domain is intended for the host machine browser.


---


## 5. Create the Pipeline Job

1. From the Jenkins dashboard, select **New Item**.

2. Enter the following item name:

   ```text
   nginx-static-site-pipeline
   ```

3. Select **Pipeline**, then select **OK**.

4. In the **Pipeline** section, configure the job as follows:

   | Field            | Value                                                       |
   | ---------------- | ----------------------------------------------------------- |
   | Definition       | `Pipeline script from SCM`                                  |
   | SCM              | `Git`                                                       |
   | Repository URL   | `http://gitea:3000/giteaadmin/nginx-static-site.git`        |
   | Credentials      | Select the Gitea credential created in the previous section |
   | Branch Specifier | `*/main`                                                    |
   | Script Path      | `Jenkinsfile`                                               |

5. Select **Save**.

> The Git SCM step requires a `Username with password` credential (Gitea username + personal access token as the password). Reserve the `Gitea Personal Access Token` credential for the Gitea Servers configuration.

> The repository URL uses the `gitea` Docker Compose service name because Jenkins accesses the repository from inside the Docker network. Do not use `gitea.local` here: that hostname is intended for the host machine.

### Run the initial build

1. Open the `nginx-static-site-pipeline` job.

2. Select **Build Now**.

3. Open the new build and select **Console Output**.

4. Confirm that the pipeline checks out the `main` branch and reaches the stages defined in the `Jenkinsfile`.

> Run the pipeline manually once before configuring the webhook. For a standard Pipeline job, the Generic Webhook Trigger configuration becomes reliably available after the job has completed its first successful run.


---


## 6. Configure Generic Webhook Trigger

1. Open the `nginx-static-site-pipeline` job and select **Configure**.

2. In the **Triggers** section, enable **Generic Webhook Trigger**.

3. Set a unique token.

4. Select **Save**.

5. Construct the webhook endpoint from the token you configured:

   ```text
   http://jenkins.local/generic-webhook-trigger/invoke?token=<WEBHOOK_TOKEN>
   ```

> Replace `<WEBHOOK_TOKEN>` with the unique value configured for this job. Do not commit this token to the repository.


---


## 7. Configure the Gitea Webhook

### Allow the Jenkins target in Gitea

The Gitea container must be allowed to send outbound webhook requests to Jenkins.

The Docker Compose configuration in this repository already sets the following Gitea environment variable:

```yaml
- GITEA__webhook__ALLOWED_HOST_LIST: jenkins
```

The `jenkins` value is the Docker Compose service name. It is resolved on the Docker network inside the Vagrant VM.

### Create the repository webhook

1. On the host machine, open the demo application repository in Gitea:

   ```text
   http://gitea.local/giteaadmin/nginx-static-site/settings/hooks
   ```

2. Select **Add Webhook** → **Gitea**.

3. Configure the webhook:

   | Field             | Value                                                                      |
   | ----------------- | -------------------------------------------------------------------------- |
   | Target URL        | `http://jenkins:8080/generic-webhook-trigger/invoke?token=<WEBHOOK_TOKEN>` |
   | HTTP Method       | `POST`                                                                     |
   | POST Content Type | `application/json`                                                         |
   | Trigger On        | `Push Events`                                                              |
   | Active            | Enabled                                                                    |

4. Select **Add Webhook**.

> Replace `<WEBHOOK_TOKEN>` with the token configured in the Jenkins job.

> The target uses the `jenkins` Docker Compose service name because Gitea sends the request from inside the Docker network. Do not use `jenkins.local` here: that domain is intended for the host machine browser.

### Test webhook delivery

1. Open the webhook entry in the repository settings.

2. Select **Test Delivery**.

3. Confirm that the latest delivery has a successful HTTP response.

4. Open Jenkins and confirm that a new build was created for the `nginx-static-site-pipeline` job.


---


## 8. Verify the Integration

1. On the Vagrant VM, open the local copy of the demo application repository.

   ```bash
   cd /home/vagrant/nginx-static-site
   ```

2. Initialize the local repository and register the Gitea remote.

   Provisioning copies the demo application files into this directory, but it does not create a Git repository. Run these commands once, before the first push:

   ```bash
   git init
   git branch -M main
   git remote add origin http://gitea.local/giteaadmin/nginx-static-site.git
   ```

   > [!TIP]
   > If the repository is already initialized, `git remote add` fails with `remote origin already exists`. Update the existing remote instead:
   >
   > ```bash
   > git remote set-url origin http://gitea.local/giteaadmin/nginx-static-site.git
   > ```

3. Make a small visible change to `index.html`.

4. Commit and push the change to the `main` branch:

   ```bash
   git add index.html
   git commit -m "test: verify webhook-triggered pipeline"
   git push -u origin main
   ```

5. On the host machine, open Jenkins at `http://jenkins.local`.

6. Confirm that a new build starts automatically for the `nginx-static-site-pipeline` job.

7. Open the build and confirm that all pipeline stages finish successfully:

   ```text
   Checkout
   Build image
   Push image
   Deploy container
   ```

8. On the host machine, open the demo application URL configured for the environment.

   > [!NOTE]
   > The pipeline deploys a container named `demo` on the `docker-cicd-demo_cicd_net` network, serving on container port `80`. Create the `app.local` proxy host in Nginx Proxy Manager with forward hostname `demo` and forward port `80`, then open `http://app.local`.

9. Confirm that the page displays the change from step 3.

A successful result validates the complete delivery path:

```text
Gitea push → Jenkins webhook → Pipeline → Docker image build → Registry push → Container deployment
```


---


## Common Issues

### Gitea webhook delivery is blocked

**Symptom:** Gitea cannot deliver the webhook, and the delivery log reports that the target host is not allowed.

**Cause:** Gitea restricts outbound webhook targets through the `ALLOWED_HOST_LIST` setting.

**Resolution:** Ensure that the Gitea service in `docker-compose.yml` contains:

```yaml
GITEA__webhook__ALLOWED_HOST_LIST: jenkins
```

Recreate the Gitea container after changing the configuration:

```bash
vagrant ssh
cd /vagrant
docker compose up -d --force-recreate gitea
```

The `jenkins` value is the Docker Compose service name. It is resolvable from the Gitea container on the Docker network inside the Vagrant VM.

### A push does not start the pipeline

**Check the following:**

- The Gitea repository webhook is active.
- The webhook target URL contains the same token configured in the Jenkins job.
- The latest webhook delivery in Gitea completed successfully.
- The Generic Webhook Trigger plugin is installed and enabled for the Jenkins job.

### Jenkins checks out the wrong branch

**Symptom:** The Pipeline job cannot find the expected branch, or it checks out `master` instead of `main`.

**Resolution:** Confirm that the demo application repository uses `main` and that the Pipeline job Branch Specifier is set to:

```text
*/main
```

The `Jenkinsfile` Checkout stage also pins the branch with `git branch: 'main', url: …`. Both the SCM Branch Specifier and the `Jenkinsfile` must reference `main`.

### Jenkins cannot use the Docker socket

**Symptom:** A pipeline stage fails with a Docker socket permission error.

**Resolution:** The custom Jenkins image aligns the `docker` group GID with the mounted Docker socket when the container starts. `docker-files/entrypoint.sh` reads the GID of the mounted `/var/run/docker.sock` and applies it to the container's `docker` group before starting Jenkins as the `jenkins` user.

Confirm that the Jenkins container was created from the project custom image and that `/var/run/docker.sock` is mounted into the container.


---


## Security Notes

This project is a local demonstration environment. Do not use its default configuration in production.

- Store the Gitea personal access token, Jenkins administrator password, and webhook token in a password manager.
- Do not commit credentials, tokens, or the `.env` file to the repository.
- Treat the Generic Webhook Trigger token as a secret. A request that contains the token can trigger the associated Jenkins job.
- Rotate the webhook token and Gitea personal access token if either value is exposed.
- The Jenkins container has access to the Docker socket. This is required for the demo pipeline to build and deploy containers, but it grants the Jenkins container privileged control over the Docker daemon.
- The Docker Registry uses HTTP and the environment does not provide TLS, high availability, backups, or production-grade access control.
