# Shopizer — CI/CD Deployment Strategy

> Fully automated pipeline: CI builds the Docker image, CD deploys it to your local machine via a self-hosted runner.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     GITHUB ACTIONS — CI (GitHub-hosted runner)               │
│                                                                             │
│  PR → Build (Maven) → Test → Docker Build → Save .tar → Upload Artifact    │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   │  CI passes + merged to 3.2.7
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     GITHUB ACTIONS — CD (Self-hosted runner on your Mac)     │
│                                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  ┌──────────────────┐  │
│  │  Download    │  │  Stop old    │  │  Load new   │  │  Run new         │  │
│  │  artifact    │─▶│  container   │─▶│  image      │─▶│  container       │  │
│  │  (.tar)      │  │              │  │             │  │  -p 8080:8080    │  │
│  └─────────────┘  └──────────────┘  └─────────────┘  └───────┬──────────┘  │
│                                                               │            │
│                                                      ┌────────▼─────────┐  │
│                                                      │  Health check    │  │
│                                                      │  localhost:8080  │  │
│                                                      └──────────────────┘  │
└──────────────────────────────────────────────────────────────┬──────────────┘
                                                               │
                    Runs directly on your Mac                  │
                                                               │
┌──────────────────────────────────────────────────────────────▼──────────────┐
│                              YOUR MAC                                       │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  GitHub Actions Runner (agent)                                        │  │
│  │  - Listens for CD jobs                                                │  │
│  │  - Executes deploy steps locally                                      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        Colima VM (Linux)                              │  │
│  │                                                                       │  │
│  │  ┌───────────────────────────────────────────────────────────────┐    │  │
│  │  │                     Docker Engine                             │    │  │
│  │  │                                                               │    │  │
│  │  │  ┌─────────────────────────────────────────────────────┐      │    │  │
│  │  │  │  Shopizer Container                                 │      │    │  │
│  │  │  │                                                     │      │    │  │
│  │  │  │  Java 11 + Spring Boot                              │      │    │  │
│  │  │  │  H2 DB (embedded)                                   │      │    │  │
│  │  │  │  Port: 8080                                         │      │    │  │
│  │  │  └─────────────────────────────────────────────────────┘      │    │  │
│  │  └───────────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              │                                              │
│                              ▼                                              │
│                 http://localhost:8080/swagger-ui.html  ✅                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## How It Works

### CI Pipeline (runs on GitHub's servers)
1. You open a PR
2. GitHub Actions builds the Java app, runs tests, builds a Docker image
3. The image is saved as a downloadable artifact

### CD Pipeline (runs on your Mac)
4. When CI passes and the PR is merged to `3.2.7`, the CD pipeline triggers
5. A self-hosted runner **on your Mac** picks up the job
6. It downloads the Docker image artifact from CI
7. Stops the old container, loads the new image, starts a new container
8. Runs a health check to confirm the app is up
9. Cleans up old images

**Zero manual steps after merge.** Code goes from PR → merged → running on your machine automatically.

---

## Self-Hosted Runner Setup

Run these once on your Mac:

```bash
# 1. Go to your repo settings
#    https://github.com/sahil-2409/shopizer/settings/actions/runners/new

# 2. Follow GitHub's instructions to download and configure the runner:
mkdir actions-runner && cd actions-runner
curl -o actions-runner-osx-arm64-2.321.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-osx-arm64-2.321.0.tar.gz
tar xzf actions-runner-osx-arm64-2.321.0.tar.gz
./config.sh --url https://github.com/sahil-2409/shopizer --token <TOKEN_FROM_GITHUB>

# 3. Start the runner
./run.sh

# Or install as a service (runs on boot):
./svc.sh install
./svc.sh start
```

> Get the exact commands and token from:
> https://github.com/sahil-2409/shopizer/settings/actions/runners/new

---

## Prerequisites

Make sure these are running on your Mac before the CD pipeline triggers:

```bash
# Colima must be running
colima start

# Self-hosted runner must be running
cd actions-runner && ./run.sh
```

---

## Cost

| Component | Cost |
|---|---|
| GitHub Actions CI | Free (public repos) |
| Self-hosted runner | Free (runs on your Mac) |
| Colima + Docker | Free |
| **Total** | **$0** |
