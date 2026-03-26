# Shopizer — Automated CI/CD Deployment Strategy

> Fully automated: push code → merge PR → app deployed. No manual steps.

---

## The Big Picture

```
 Developer pushes code
        │
        ▼
 ┌──────────────┐       ┌──────────────┐       ┌──────────────────────┐
 │  Open PR     │──────▶│  CI Pipeline │──────▶│  Merge to 3.2.7     │
 │              │       │  (automated) │       │  (manual approval)   │
 └──────────────┘       └──────────────┘       └──────────┬───────────┘
                                                          │
                                                          ▼
                                                ┌──────────────────────┐
                                                │  CD Pipeline         │
                                                │  (fully automated)   │
                                                └──────────┬───────────┘
                                                           │
                                                           ▼
                                                ┌──────────────────────┐
                                                │  App live on         │
                                                │  localhost:8080  ✅  │
                                                └──────────────────────┘
```

---

## Detailed Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  PHASE 1: CI — Runs on GitHub's servers (GitHub-hosted runner)              │
│  Trigger: Every PR to 3.2.7                                                │
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────────┐    ┌────────────────┐    │
│  │  Build   │───▶│  Test    │───▶│  Docker      │───▶│  Save image   │    │
│  │  Maven   │    │  Maven   │    │  Build       │    │  as artifact  │    │
│  │  package │    │  verify  │    │  image       │    │  (.tar → zip) │    │
│  └──────────┘    └──────────┘    └──────────────┘    └────────────────┘    │
│                                                                             │
│  If any step fails → PR is blocked from merging                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                          PR merged to 3.2.7 (triggers CD)
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  PHASE 2: CD — Runs on your Mac (Self-hosted runner)                        │
│  Trigger: CI passes + merge to 3.2.7                                        │
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │  Download    │  │  Stop old    │  │  Load new   │  │  Start new     │  │
│  │  image       │─▶│  container   │─▶│  image      │─▶│  container     │  │
│  │  artifact    │  │              │  │             │  │  port 8080     │  │
│  └──────────────┘  └──────────────┘  └─────────────┘  └───────┬────────┘  │
│                                                               │           │
│                                                      ┌────────▼────────┐  │
│                                                      │  Health check   │  │
│                                                      │  Retry 30x      │  │
│                                                      │  until 200 OK   │  │
│                                                      └────────┬────────┘  │
│                                                               │           │
│                                                      ┌────────▼────────┐  │
│                                                      │  Cleanup old    │  │
│                                                      │  images         │  │
│                                                      └─────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  PHASE 3: RUNNING — Your Mac (Colima + Docker)                              │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  Colima VM                                                            │  │
│  │  ┌───────────────────────────────────────────────────────────────┐    │  │
│  │  │  Docker Engine                                                │    │  │
│  │  │  ┌─────────────────────────────────────────────────────┐      │    │  │
│  │  │  │  Shopizer Container                                 │      │    │  │
│  │  │  │  Java 11 + Spring Boot + H2 DB                      │      │    │  │
│  │  │  │  Port: 8080                                         │      │    │  │
│  │  │  └─────────────────────────────────────────────────────┘      │    │  │
│  │  └───────────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              │                                              │
│                              ▼                                              │
│                 http://localhost:8080/swagger-ui.html  ✅                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## What Happens When You Push Code

| Step | What | Where | Automated? |
|------|-------|-------|------------|
| 1 | Open PR | GitHub | You do this |
| 2 | Build Java app | GitHub runner | ✅ Auto |
| 3 | Run tests | GitHub runner | ✅ Auto |
| 4 | Build Docker image | GitHub runner | ✅ Auto |
| 5 | Save image as artifact | GitHub runner | ✅ Auto |
| 6 | Merge PR | GitHub | You do this |
| 7 | Download artifact | Your Mac (runner) | ✅ Auto |
| 8 | Stop old container | Your Mac (runner) | ✅ Auto |
| 9 | Load new image | Your Mac (runner) | ✅ Auto |
| 10 | Start new container | Your Mac (runner) | ✅ Auto |
| 11 | Health check | Your Mac (runner) | ✅ Auto |
| 12 | App live on localhost:8080 | Your Mac | ✅ Done |

**You only do 2 things: open a PR and merge it. Everything else is automated.**

---

## One-Time Setup

### 1. Install Colima & Docker

```bash
brew install colima docker
colima start
```

### 2. Set Up Self-Hosted Runner

Go to: https://github.com/sahil-2409/shopizer/settings/actions/runners/new

```bash
mkdir actions-runner && cd actions-runner
# Download runner (follow GitHub's instructions for exact version)
curl -o actions-runner-osx-arm64-2.321.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-osx-arm64-2.321.0.tar.gz
tar xzf actions-runner-osx-arm64-2.321.0.tar.gz

# Configure
./config.sh --url https://github.com/sahil-2409/shopizer --token <TOKEN_FROM_GITHUB>

# Install as service (starts on boot)
./svc.sh install
./svc.sh start
```

### 3. Done

From now on, every merge to `3.2.7` auto-deploys to your machine.

---

## Rollback

If a bad version gets deployed:

```bash
# Check available images
docker images | grep shopizer

# Run a previous version
docker stop shopizer && docker rm shopizer
docker run -d -p 8080:8080 --name shopizer shopizer:<previous-sha>
```

---

## Prerequisites Checklist

Before the CD pipeline can deploy, ensure:

- [x] Colima is running (`colima status`)
- [x] Self-hosted runner is running (`cd actions-runner && ./svc.sh status`)
- [x] Port 8080 is available

---

## Cost

| Component | Cost |
|---|---|
| GitHub Actions CI | Free |
| Self-hosted runner | Free (your Mac) |
| Colima + Docker | Free |
| **Total** | **$0** |
