# Web App: Cloud-Native User Management API

A **Spring Boot 3** REST API for user accounts (sign-up, email verification, profile read/update), deployed on **Google Cloud** as an immutable VM image behind a global HTTPS load balancer. Infrastructure is in [tf-gcp-infra](https://github.com/ShashikarNEU/tf-gcp-infra). The email verification function is in [serverless-fork](https://github.com/ShashikarNEU/serverless-fork).

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Java 17, Spring Boot 3.2, Spring Data JPA (Hibernate), Lombok |
| Database | MySQL (Cloud SQL, private IP) |
| Auth | HTTP Basic Auth, passwords hashed with BCrypt |
| Messaging | Google Cloud Pub/Sub (publishes verification events) |
| Logging | Log4j2 JSON logs, shipped by the Google Ops Agent to Cloud Logging |
| Image | Packer (`googlecompute`), CentOS, app runs as a `nologin` system user under systemd |
| Infra | Terraform ([tf-gcp-infra](https://github.com/ShashikarNEU/tf-gcp-infra)) |
| CI/CD | GitHub Actions |

---

## API

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/v1/user` | No | Create a user. Publishes a verification event to Pub/Sub |
| GET | `/v1/user/verify?token=<uuid>:<email>` | No | Verify the email (link expires 2 minutes after it's sent) |
| GET | `/v1/user/self` | Basic | Get your profile (verified users only) |
| PUT | `/v1/user/self` | Basic | Update first name, last name or password (verified users only) |
| GET | `/healthz` | No | 200 if the database is reachable, 503 if not. Used by the LB and auto-healing |

`HEAD` and `OPTIONS` on these paths return `405`. Unknown JSON fields are rejected with `400`.

### Create a user

```bash
curl -X POST https://<your-domain>/v1/user \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user@example.com",
    "password": "securePassword123",
    "first_name": "John",
    "last_name": "Doe"
  }'
```

`201 Created`:

```json
{
  "id": "uuid",
  "first_name": "John",
  "last_name": "Doe",
  "username": "user@example.com",
  "account_created": "...",
  "account_updated": "..."
}
```

### Get your profile

```bash
curl https://<your-domain>/v1/user/self -u "user@example.com:securePassword123"
```

---

## Sign-up and verification flow

```
POST /v1/user
  -> validate, BCrypt-hash password, save to Cloud SQL
  -> generate UUID token, publish "<uuid>:<email>" to Pub/Sub topic verify-email
       -> Cloud Function sends the link via Mailgun and sets email_expiry_time = now + 2 min
GET /v1/user/verify?token=...
  -> token matches and not expired -> user marked verified
Authenticated endpoints reject unverified users.
```

---

## Deployment

```
PR to main
  ├─ maven-compile.yml   mvn compile
  ├─ maven-test.yml      integration tests against MySQL on the runner
  └─ packer_pr.yml       build JAR, packer fmt -check + validate

Merge to main (packer_merge.yml)
  1. Build the JAR, bake a new image with Packer
     (Java 17, JAR, systemd unit, Ops Agent, csye6225 nologin user)
  2. Create a new regional instance template from that image:
     no external IP, CMEK boot disk, cloud-platform scope, boot script deploy/startup.sh
  3. Point the managed instance group at it and start a rolling update
     (max-surge 3, max-unavailable 0, so capacity never drops)
  4. Wait until every VM runs the new version
```

At boot, `deploy/startup.sh` reads the DB settings from **Secret Manager** using the VM's service account and writes `/opt/.env` (mode 600). No credentials are stored in instance metadata.

### GitHub secrets used

| Secret | Purpose |
|--------|---------|
| `GCP_CREDENTIALS` | Service-account key used by the GCP auth steps |
| `project_id`, `REGION`, `GCLOUD_NETWORK`, `SUBNET` | Where templates are created |
| `INSTANCE_GRP_MANAGER`, `INSTANCE_TEMPLATE`, `ROLLING_ACTION_TYPE` | Which MIG to roll and how |
| `MACHINE_TYPE`, `VM_DISK_SIZE`, `VM_DISK_TYPE`, `VM_INSTANCE_SERVICE_ACCOUNT` | Template settings |
| `PKR_VAR_*` values (`source_image`, `zone`, `ssh_username`, ...) | Packer build settings |
| `DATABASE_URL`, `DATABASE_USERNAME`, `DATABASE_PASSWORD` | MySQL on the CI runner for tests |

---

## Local development

Prerequisites: Java 17, Maven 3.6+, MySQL 8.

The app reads its datasource from environment variables (or a `.env` file in the working directory):

```bash
export DATABASE_URL="jdbc:mysql://localhost:3306/cloudDatabase?createDatabaseIfNotExist=true"
export DATABASE_USERNAME=root
export DATABASE_PASSWORD=<password>

./mvnw spring-boot:run      # http://localhost:8080
./mvnw test
```

Sign-up publishes to Pub/Sub, so creating users locally needs Google credentials (`gcloud auth application-default login`) with access to the topic.

---

## Repository layout

```
webapp/
├── src/main/java/com/csye6225/webapp/   controllers, services, JPA entity, exception handlers
├── src/main/resources/                  application.properties, log4j2-spring.xml (JSON logs)
├── src/test/                            integration tests
├── packer/                              image template, systemd unit, provisioning scripts
├── deploy/startup.sh                    VM boot script (reads Secret Manager)
└── .github/workflows/                   CI and deploy pipelines
```

---

## Related repositories

- [tf-gcp-infra](https://github.com/ShashikarNEU/tf-gcp-infra): VPC, MIG, load balancer, Cloud SQL, KMS, Secret Manager, alerts
- [serverless-fork](https://github.com/ShashikarNEU/serverless-fork): Pub/Sub-triggered Cloud Function that sends verification emails
