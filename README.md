
# TaskApp — Production Kubernetes Deployment on AWS

A full-stack task management application deployed on a production-grade multi-node Kubernetes cluster on AWS, built with infrastructure automation, GitOps delivery, and HTTPS.

---

## Overview

TaskApp is a full-stack application consisting of:

- **Frontend** — React with Nginx
- **Backend** — Flask REST API
- **Database** — PostgreSQL

The goal of this deployment was to move beyond single-server deployments and build a production-style cloud-native platform that is reproducible, scalable, and automated end to end.

---

## Architecture

```
User Browser
    |
    | HTTPS
    v
Traefik Ingress Controller
    |
    +----------------------+
    |                      |
    v                      v
Frontend Service       Backend Service
(2 replicas)          (2 replicas)
                           |
                           v
                    PostgreSQL StatefulSet
                    PersistentVolumeClaim
```

**Infrastructure:**

```
AWS EC2 — Control Plane Node (k3s server)
AWS EC2 — Worker Node 1    (k3s agent)
AWS EC2 — Worker Node 2    (k3s agent)
```

**Automation flow:**

```
Terraform → AWS infrastructure provisioning
Ansible   → k3s Kubernetes cluster setup
Argo CD   → GitOps application deployment
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure | AWS EC2, VPC, Security Groups |
| IaC | Terraform with S3 remote state + DynamoDB lock |
| Configuration | Ansible (roles: common, k3s-server, k3s-agent) |
| Container Runtime | k3s (lightweight Kubernetes) |
| GitOps | Argo CD |
| Ingress | Traefik Ingress Controller |
| TLS | cert-manager + Let's Encrypt |
| Autoscaling | HorizontalPodAutoscaler |
| Reliability | PodDisruptionBudget, topology spread constraints |
| Observability | metrics-server |
| Images | GitHub Container Registry (GHCR) — pinned SHA tags |

---

## Infrastructure

Provisioned using modular Terraform:

- **Network module** — VPC, public subnet, internet gateway, route table
- **Security group module** — least privilege: SSH restricted to my IP, Kubernetes API not exposed to internet
- **Compute module** — 1 control plane + 2 worker EC2 nodes

Remote state stored in S3 with DynamoDB state locking. No `terraform.tfstate` committed to Git.

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

---

## Cluster Setup

Ansible playbook installs k3s across all nodes using idempotent roles:

- `common` — server hardening, non-root user, SSH keys, ufw firewall
- `k3s-server` — installs k3s on control plane, captures node token
- `k3s-agent` — joins worker nodes to the cluster using the token

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

Verify cluster:

```bash
kubectl get nodes -o wide
```

Expected output:

```
NAME              STATUS   ROLES          
control-plane     Ready    control-plane  
worker-1          Ready    worker         
worker-2          Ready    worker         
```

---

## Application Deployment

### GitOps with Argo CD

Application state is managed entirely through Git. Argo CD watches this repository and automatically syncs changes to the cluster.

```bash
kubectl apply -f gitops/application.yaml
```

After this single command Argo CD takes ownership. All future deployments happen through Git commits — no manual `kubectl apply` in the final state.

```
Git commit → Git push → Argo CD detects change → Cluster synced
```

### Kubernetes Manifests

```
manifests/app/
├── namespace.yaml
├── configmap.yaml
├── secret.yaml
├── postgres-statefulset.yaml
├── postgres-service.yaml
├── backend-deployment.yaml
├── backend-service.yaml
├── frontend-deployment.yaml
├── frontend-service.yaml
├── migration-job.yaml
├── ingress.yaml
├── clusterissuer.yaml
├── hpa.yaml
└── pdb.yaml
```

### Key Design Decisions

**PostgreSQL as StatefulSet**
PostgreSQL runs as a StatefulSet with a PersistentVolumeClaim ensuring data survives pod restarts and rescheduling.

**Database migrations as a Job**
Migrations run as a dedicated Kubernetes Job before the backend replicas start. This prevents race conditions when multiple replicas attempt `alembic upgrade head` simultaneously.

**Replica spread across nodes**
Frontend and backend both run 2 replicas with topology spread constraints ensuring replicas land on different worker nodes — no single point of failure.

**HorizontalPodAutoscaler**
Backend scales automatically between 2 and 5 replicas based on CPU utilisation at 60% threshold.

**PodDisruptionBudget**
Ensures at least one replica remains available during voluntary disruptions such as node drains.

**Pinned image tags**
All images use pinned commit SHA tags. No `:latest` anywhere in the deployment.

```
ghcr.io/ts-a-devops/taskapp-backend:5d6b8fc
ghcr.io/ts-a-devops/taskapp-frontend:26da2b0
```

---

## TLS and HTTPS

cert-manager issues and renews TLS certificates automatically using Let's Encrypt.

ClusterIssuer configured for HTTP-01 challenge via Traefik Ingress.

Verified with:

```bash
kubectl get certificate -n taskapp
# NAME          READY   SECRET
# taskapp-tls   True    taskapp-tls

curl -I https://taskapp.3.145.114.141.sslip.io
# HTTP/2 200
```

---

## Evidence

Screenshots and logs proving the deployment are stored in `docs/EVIDENCE/`:

- Multi-node cluster Ready
- Pods spread across different nodes
- Valid HTTPS certificate
- PostgreSQL data surviving pod deletion
- Zero-downtime rolling deployment
- HPA scaling under load
- Argo CD synced and healthy

---

## Repository Structure

```
capstone-phoenix/
├── infra/
│   ├── terraform/          # Modular Terraform — VPC, SG, EC2
│   └── ansible/            # Roles — common, k3s-server, k3s-agent
├── manifests/
│   └── app/                # All Kubernetes manifests
├── gitops/
│   └── application.yaml    # Argo CD Application manifest
└── docs/
    ├── ARCHITECTURE.md
    ├── RUNBOOK.md
    ├── COST.md
    └── EVIDENCE/
```

---

## Running Locally

```bash
# Clone the repository
git clone https://github.com/seunjosh/TaskApp-Devops-project.git
cd TaskApp-Devops-project

# Provision infrastructure
cd infra/terraform
terraform init && terraform apply

# Configure cluster
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# Deploy via GitOps
kubectl apply -f gitops/application.yaml
# Argo CD takes over from here
```

---

## Cost

Infrastructure was provisioned on AWS us-east-2 using t3.small instances.

Monthly cost breakdown documented in `docs/COST.md`.

Infrastructure has been shut down after project completion to avoid ongoing costs. Full deployment evidence is available in `docs/EVIDENCE/`.

---

## Author

**Joshua Oyewole**
Cloud and DevOps Engineer

- GitHub: [github.com/seunjosh](https://github.com/seunjosh)
- LinkedIn: [linkedin.com/in/joshua-oyewole-63a3179b](https://linkedin.com/in/joshua-oyewole-63a3179b)

---

## Prerequisites

To reproduce this deployment you will need:

- AWS account with IAM user and access keys
- Terraform v1.5+ installed locally
- Ansible installed locally
- kubectl installed locally
- A key pair created in AWS EC2
- SSH access to EC2 instances

---

## Security

This deployment follows security best practices:

- SSH access restricted to a single IP address only
- Kubernetes API port 6443 not exposed to the internet
- Node-to-node traffic restricted within the cluster security group
- No secrets committed to Git — all sensitive values in Kubernetes Secrets
- No plaintext passwords in configmaps or environment variables
- No `:latest` image tags — all images pinned to commit SHA
- No `terraform.tfstate` or kubeconfig files committed to Git
- TLS enforced end to end with real Let's Encrypt certificates

---

## Challenges and Solutions

**Python version compatibility**
Initial EC2 instance used Ubuntu 26.04 with Python 3.14 which broke psycopg2-binary installation. Resolved by switching to Ubuntu 22.04 with Python 3.12 — a good reminder that stability matters more than novelty in production environments.

**GitHub authentication**
GitHub removed password authentication for Git operations. Resolved using Personal Access Tokens with the Git credential helper for persistent authentication in WSL.

**Argo CD CRD installation**
One CRD apply failed during Argo CD installation due to annotation size limits. Resolved using server-side apply flag which bypasses the annotation size restriction.

**Kubernetes API vs application availability**
Encountered a TLS handshake timeout on the Kubernetes API while the application itself remained accessible. This reinforced an important distinction — application availability and cluster API availability are separate concerns with separate security group rules.

**Understanding execution context**
Several commands failed because they were run on the EC2 control plane instead of the local WSL machine where the Git repository lived. This reinforced the importance of always knowing where you are: local machine, remote server, or inside the Kubernetes cluster.

---

## What This Project Demonstrates

- Infrastructure as Code with Terraform — reproducible, modular, no manual console clicks
- Configuration management with Ansible — idempotent, role-based server provisioning
- Kubernetes production patterns — StatefulSets, probes, resource limits, rolling updates
- GitOps with Argo CD — desired state in Git, cluster self-healing toward that state
- Automated TLS — cert-manager removes manual certificate management entirely
- High availability — multiple replicas spread across nodes with disruption budgets
- Autoscaling — HPA responds to real load without manual intervention

---

## Lessons Learned

**Infrastructure should be code**
Terraform made it possible to destroy and recreate the entire AWS infrastructure from a single command. Manual console setups cannot be reproduced reliably.

**Kubernetes changes how you think about applications**
A single server hides many assumptions. Kubernetes forces you to think explicitly about storage, scheduling, health, replicas, and disruption. Every assumption that worked on one box must be solved explicitly on a cluster.

**GitOps improves deployment discipline**
With Argo CD the cluster state is always traceable to a Git commit. There is no ambiguity about what is deployed or who changed it.

**Separate concerns properly**
The migration Job pattern solved a real race condition that would have caused failures at scale. Separating concerns — migrations from running replicas — is not just good practice, it is necessary at 2+ replicas.
