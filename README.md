# Web App — Cloud-Native User Management API

A production-grade **RESTful API** for managing user accounts, built with **Spring Boot** and deployed on **Google Cloud Platform**. Features secure token-based authentication, automated CI/CD with GitHub Actions, and cloud-native integrations including Pub/Sub messaging and email verification.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Java 17, Spring Boot 3.2.2 |
| Database | MySQL (Cloud SQL on GCP) |
| Authentication | HTTP Basic Auth with BCrypt password hashing |
| Cloud | Google Cloud Platform (Compute Engine, Cloud SQL, Pub/Sub, Cloud Storage) |
| Infrastructure | Terraform (via [tf-gcp-infra](https://github.com/ShashikarNEU/tf-gcp-infra)) |
| CI/CD | GitHub Actions |
| Build | Maven |

---

## Features

- **User Registration** — Create accounts with email, password, first/last name
- **Secure Authentication** — HTTP Basic Auth with BCrypt hashing (no plaintext passwords ever stored)
- **Profile Management** — Retrieve and update user information
- **Email Verification** — New users receive a verification email via GCP Pub/Sub + Cloud Functions
- **Token-Based Access Control** — Authenticated endpoints require valid credentials
- **CI/CD Pipeline** — GitHub Actions compiles, tests, and validates every pull request
- **Branch Protection** — PRs can only merge if GitHub Actions workflow passes
- **Cloud Deployment** — Runs on GCP Compute Engine with auto-scaling and load balancing

---

## API Endpoints

### User Management

| Method | Endpoint | Auth Required | Description |
|--------|----------|---------------|-------------|
| POST | `/v1/user` | No | Create a new user account |
| GET | `/v1/user/self` | Yes | Get current user's profile |
| PUT | `/v1/user/self` | Yes | Update current user's profile |

### Health Check

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/healthz` | Application health check |

---

## Request & Response Examples

### Create a User

```bash
curl -X POST http://localhost:8080/v1/user \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securePassword123",
    "first_name": "John",
    "last_name": "Doe"
  }'
```

**Response** `201 Created`:
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "account_created": "2024-01-01T00:00:00Z",
  "account_updated": "2024-01-01T00:00:00Z"
}
```

### Get User Profile

```bash
curl -X GET http://localhost:8080/v1/user/self \
  -u "user@example.com:securePassword123"
```

---

## Local Development Setup

### Prerequisites

- Java 17+
- Maven 3.6+
- MySQL 8.0+

### 1. Clone the Repository

```bash
git clone https://github.com/ShashikarNEU/webapp.git
cd webapp
```

### 2. Configure the Database

Update `src/main/resources/application.properties`:

```properties
spring.datasource.url=jdbc:mysql://localhost:3306/userdb
spring.datasource.username=your_username
spring.datasource.password=your_password
spring.jpa.hibernate.ddl-auto=update
```

### 3. Build and Run

```bash
# Build
./mvnw clean install

# Run
./mvnw spring-boot:run
```

App runs at `http://localhost:8080`.

---

## CI/CD Pipeline

GitHub Actions workflow on every pull request:

1. Checks out the code
2. Sets up Java 17
3. Runs `mvn compile` to validate the build
4. PR can only be merged if the workflow passes (branch protection enforced)

---

## Cloud Architecture

```
Internet → Load Balancer → Compute Engine (Auto-scaling MIG)
                                  ↓
                           Spring Boot App
                                  ↓
                    ┌─────────────┴──────────────┐
                    ↓                            ↓
               Cloud SQL (MySQL)          GCP Pub/Sub
                                               ↓
                                      Cloud Functions
                                      (Email Verification)
```

---

## Related Repositories

- [tf-gcp-infra](https://github.com/ShashikarNEU/tf-gcp-infra) — Terraform infrastructure for this app
- [serverless-fork](https://github.com/ShashikarNEU/serverless-fork) — Cloud Functions for email verification
