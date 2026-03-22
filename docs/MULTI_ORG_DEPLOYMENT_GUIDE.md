# Multi-Org Deployment Guide — Package-Based Monorepo

> **Purpose**: Technical reference for the package-based monorepo multi-org CI/CD deployment strategy.  
> **Certification**: Salesforce Development and Deployment Lifecycle Architect.  
> **Audience**: Team, TA, Notebook LM, Gemini.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Package Structure](#package-structure)
3. [Multi-Org Mapping](#multi-org-mapping)
4. [GitHub Secrets Setup](#github-secrets-setup)
5. [Validation Pipeline (validate.yml)](#validation-pipeline)
6. [Deployment Pipeline (deploy.yml)](#deployment-pipeline)
7. [Path-Based Change Detection](#path-based-change-detection)
8. [Deployment Scenarios](#deployment-scenarios)
9. [sfdx-project.json Explained](#sfdx-projectjson-explained)
10. [Developer Workflow](#developer-workflow)
11. [Certification Domain Mapping](#certification-domain-mapping)
12. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### The Problem

A single `force-app/` folder deployed to a single org means every metadata change goes everywhere. In a multi-org enterprise, different business units (healthcare, finance) need their own org with only their metadata.

### The Solution

A **package-based monorepo** with folder-per-org routing:

```
                        Single Git Repository
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
    force-app/core     force-app/healthcare    force-app/finance
    (shared code)       (Projects A & B)        (Project C)
          │                    │                    │
          │            ┌───────┘                    │
          │            │                            │
          ▼            ▼                            ▼
    ┌─────────────────────┐              ┌─────────────────────┐
    │      Org 1          │              │      Org 2          │
    │  (Healthcare)       │              │  (Finance)          │
    │                     │              │                     │
    │  • Bedrock-Core     │              │  • Bedrock-Core     │
    │  • Bedrock-Healthcare│             │  • Bedrock-Finance  │
    └─────────────────────┘              └─────────────────────┘
```

### Key Principles

- **Core is shared**: Deployed to ALL orgs when it changes.
- **Domain packages are isolated**: Healthcare only goes to Org 1. Finance only goes to Org 2.
- **One repo, many orgs**: No repo duplication. One source of truth.
- **Change detection**: Only deploy what changed, to the right org.

---

## Package Structure

### Directory Layout

```
deploymentBadgeDemo/
├── force-app/
│   ├── core/                           ← Bedrock-Core (shared across all orgs)
│   │   └── main/default/
│   │       └── classes/
│   │           ├── BedrockLogger.cls
│   │           ├── BedrockLogger.cls-meta.xml
│   │           ├── TestBedrockLogger.cls
│   │           └── TestBedrockLogger.cls-meta.xml
│   │
│   ├── healthcare/                     ← Bedrock-Healthcare (Org 1 only)
│   │   └── main/default/
│   │       └── classes/
│   │           ├── PatientService.cls
│   │           ├── PatientService.cls-meta.xml
│   │           ├── TestPatientService.cls
│   │           └── TestPatientService.cls-meta.xml
│   │
│   ├── finance/                        ← Bedrock-Finance (Org 2 only)
│   │   └── main/default/
│   │       └── classes/
│   │           ├── InvoiceService.cls
│   │           ├── InvoiceService.cls-meta.xml
│   │           ├── TestInvoiceService.cls
│   │           └── TestInvoiceService.cls-meta.xml
│   │
│   └── test/                           ← Jest mocks (not a Salesforce package)
│       └── jest-mocks/
│
├── .github/workflows/
│   ├── validate.yml                    ← PR validation (dry-run)
│   └── deploy.yml                      ← Multi-org deployment
│
└── sfdx-project.json                   ← Package definitions + dependencies
```

### Package Dependencies

```
Bedrock-Core (shared)
       │
       ├──── Bedrock-Healthcare (depends on Core)
       │
       └──── Bedrock-Finance (depends on Core)
```

This means:
- Core must be deployed **before** healthcare or finance.
- Healthcare and finance do **not** depend on each other.
- Healthcare and finance can deploy in **parallel**.

---

## Multi-Org Mapping

| Package | Folder | Deployed To | Secret |
|---------|--------|-------------|--------|
| **Bedrock-Core** | `force-app/core/` | Org 1 AND Org 2 | Both secrets |
| **Bedrock-Healthcare** | `force-app/healthcare/` | Org 1 only | `SFDX_URL_HEALTHCARE` |
| **Bedrock-Finance** | `force-app/finance/` | Org 2 only | `SFDX_URL_FINANCE` |

---

## GitHub Secrets Setup

### Required Secrets

Go to **Repository → Settings → Secrets and variables → Actions** and create:

| Secret Name | Purpose | Value |
|-------------|---------|-------|
| `SFDX_URL_HEALTHCARE` | Healthcare org (Org 1) — deploy and PR validate | Auth URL for healthcare org |
| `SFDX_URL_FINANCE` | Finance org (Org 2) — deploy and PR validate | Auth URL for finance org |

### How to Generate an Auth URL

```bash
# Log in to the org
sf org login web --alias myOrg

# Display the auth URL (copy the sfdxAuthUrl value)
sf org display --verbose --json --target-org myOrg
```

Copy the `sfdxAuthUrl` field and paste it as the secret value.

### No Environments Needed

This approach uses **repository-level secrets only**. No GitHub Environments are required. The workflow routes to the correct org by using different secrets in different jobs.

---

## Validation Pipeline

**File**: `.github/workflows/validate.yml`

### When It Runs

- On pull request to `main`
- Only when `force-app/**` changes

### What It Does

1. **detect-changes** — same path filters as deploy (`core`, `healthcare`, `finance`)
2. **validate-healthcare** — if core or healthcare changed: authenticate with `SFDX_URL_HEALTHCARE`, run `sf project deploy validate` for the matching folder(s) (same routing idea as deploy)
3. **validate-finance** — if core or finance changed: same with `SFDX_URL_FINANCE`
4. **apex-scan** — when any of those packages changed: delta vs PR base, Salesforce Code Analyzer, SARIF upload

### Why validate each org?

Core and package metadata are validated against the **same orgs** that receive deploys, so org-specific constraints and tests match production targets.

---

## Deployment Pipeline

**File**: `.github/workflows/deploy.yml`

### When It Runs

- On push to `main` (typically after PR merge)
- Only when `force-app/**` changes

### Jobs

The pipeline has **3 jobs**:

```
┌──────────────────┐
│  detect-changes   │  Job 1: Determine which folders changed
└───────┬──────────┘
        │
        │  outputs: core=true/false, healthcare=true/false, finance=true/false
        │
        ├─────────────────────────────┐
        ▼                             ▼
┌──────────────────┐       ┌──────────────────┐
│ deploy-healthcare │       │ deploy-finance    │
│                  │       │                  │
│ Runs if:         │       │ Runs if:         │
│ core OR          │       │ core OR          │
│ healthcare       │       │ finance          │
│ changed          │       │ changed          │
│                  │       │                  │
│ Authenticates    │       │ Authenticates    │
│ with:            │       │ with:            │
│ SFDX_URL_        │       │ SFDX_URL_        │
│ HEALTHCARE       │       │ FINANCE          │
│                  │       │                  │
│ Deploys:         │       │ Deploys:         │
│ 1. core (if chg) │       │ 1. core (if chg) │
│ 2. healthcare    │       │ 2. finance       │
│                  │       │                  │
│ → Org 1          │       │ → Org 2          │
└──────────────────┘       └──────────────────┘
       (parallel)                (parallel)
```

### Job 1: detect-changes

```yaml
detect-changes:
  runs-on: ubuntu-latest
  outputs:
    core: ${{ steps.filter.outputs.core }}
    healthcare: ${{ steps.filter.outputs.healthcare }}
    finance: ${{ steps.filter.outputs.finance }}
  steps:
    - uses: actions/checkout@v3
    - uses: dorny/paths-filter@v3
      id: filter
      with:
        filters: |
          core:
            - 'force-app/core/**'
          healthcare:
            - 'force-app/healthcare/**'
          finance:
            - 'force-app/finance/**'
```

- **Action**: `dorny/paths-filter@v3` checks which folders changed in the push.
- **Outputs**: Boolean flags (`true`/`false`) for each package.
- **Why**: Downstream jobs use these flags to decide whether to run.

### Job 2: deploy-healthcare

- **Condition**: Runs if `core == true` OR `healthcare == true`.
- **Auth**: Uses `SFDX_URL_HEALTHCARE` secret.
- **Deploys**: Core first (if changed), then healthcare.
- **Target**: Org 1 (Healthcare).

### Job 3: deploy-finance

- **Condition**: Runs if `core == true` OR `finance == true`.
- **Auth**: Uses `SFDX_URL_FINANCE` secret.
- **Deploys**: Core first (if changed), then finance.
- **Target**: Org 2 (Finance).

---

## Path-Based Change Detection

### How `dorny/paths-filter` Works

1. Compares the pushed commit with its parent.
2. Checks which files changed.
3. Matches changed file paths against the defined filters.
4. Outputs `true` or `false` for each filter.

### Filter Definitions

| Filter | Matches | Triggers |
|--------|---------|----------|
| `core` | `force-app/core/**` | deploy-healthcare AND deploy-finance |
| `healthcare` | `force-app/healthcare/**` | deploy-healthcare only |
| `finance` | `force-app/finance/**` | deploy-finance only |

### Why Core Triggers Both

Because both healthcare and finance depend on core:

```yaml
# deploy-healthcare runs if:
if: needs.detect-changes.outputs.core == 'true' || needs.detect-changes.outputs.healthcare == 'true'

# deploy-finance runs if:
if: needs.detect-changes.outputs.core == 'true' || needs.detect-changes.outputs.finance == 'true'
```

---

## Deployment Scenarios

### Scenario 1: Only Healthcare Changes

| Changed | detect-changes | deploy-healthcare | deploy-finance |
|---------|---------------|-------------------|----------------|
| `force-app/healthcare/` | healthcare=true | RUNS: deploys healthcare to Org 1 | SKIPPED |

### Scenario 2: Only Finance Changes

| Changed | detect-changes | deploy-healthcare | deploy-finance |
|---------|---------------|-------------------|----------------|
| `force-app/finance/` | finance=true | SKIPPED | RUNS: deploys finance to Org 2 |

### Scenario 3: Core Changes

| Changed | detect-changes | deploy-healthcare | deploy-finance |
|---------|---------------|-------------------|----------------|
| `force-app/core/` | core=true | RUNS: deploys core to Org 1 | RUNS: deploys core to Org 2 |

### Scenario 4: Healthcare + Finance Change Together

| Changed | detect-changes | deploy-healthcare | deploy-finance |
|---------|---------------|-------------------|----------------|
| `force-app/healthcare/` + `force-app/finance/` | healthcare=true, finance=true | RUNS: deploys healthcare to Org 1 | RUNS: deploys finance to Org 2 |

### Scenario 5: Core + Healthcare Change

| Changed | detect-changes | deploy-healthcare | deploy-finance |
|---------|---------------|-------------------|----------------|
| `force-app/core/` + `force-app/healthcare/` | core=true, healthcare=true | RUNS: deploys core + healthcare to Org 1 | RUNS: deploys core to Org 2 |

---

## sfdx-project.json Explained

```json
{
  "packageDirectories": [
    {
      "path": "force-app/core",
      "package": "Bedrock-Core",
      "default": true
    },
    {
      "path": "force-app/healthcare",
      "package": "Bedrock-Healthcare",
      "dependencies": [{ "package": "Bedrock-Core" }]
    },
    {
      "path": "force-app/finance",
      "package": "Bedrock-Finance",
      "dependencies": [{ "package": "Bedrock-Core" }]
    }
  ],
  "namespace": "",
  "sourceApiVersion": "65.0"
}
```

| Field | Purpose |
|-------|---------|
| `path` | Folder location for this package's metadata |
| `package` | Package name (used in dependencies and CLI commands) |
| `default` | Default target for `sf project generate` commands |
| `dependencies` | Packages that must be deployed before this one |
| `sourceApiVersion` | Salesforce API version for metadata |

---

## Developer Workflow

### Day-to-Day Development

1. **Create a branch** from `main`.
2. **Add metadata** to the correct package folder:
   - Shared utility? → `force-app/core/`
   - Healthcare feature? → `force-app/healthcare/`
   - Finance feature? → `force-app/finance/`
3. **Open a PR** to `main` → validation runs.
4. **Merge** → deployment routes to the correct org(s).

### CLI Commands for Package-Specific Work

```bash
# Generate an Apex class in the healthcare package
sf project generate apex class --name MyService --output-dir force-app/healthcare/main/default/classes

# Deploy only healthcare locally (testing)
sf project deploy start --source-dir force-app/healthcare --target-org myOrg

# Deploy core + healthcare together
sf project deploy start --source-dir force-app/core --source-dir force-app/healthcare --target-org myOrg

# Retrieve into the finance package
sf project retrieve start --metadata ApexClass:MyClass --output-dir force-app/finance --target-org myFinanceOrg
```

### Rules

- Never put healthcare-specific code in `force-app/finance/` (or vice versa).
- Shared utilities belong in `force-app/core/`.
- Always commit both `.cls` and `.cls-meta.xml` together.
- Test classes go in the same package as the class they test.

---

## Certification Domain Mapping

| Certification Domain | How This Demo Addresses It |
|----------------------|----------------------------|
| **Application Lifecycle Management** | Package-based monorepo, PR gating, branch strategy |
| **Deploying** | Multi-org deployment via folder routing, `sf project deploy start` per package |
| **Building** | Source format packages, delta detection, `sfdx-project.json` dependencies |
| **Releasing** | Path-filtered workflows, parallel deployment jobs, conditional execution |
| **Testing** | `RunLocalTests` during validation, test classes per package |
| **System Design** | Package dependency graph, shared core architecture, org isolation |
| **Risk & Methodology Tools** | PMD scanner, SARIF, secrets management (no credentials in repo) |

---

## Troubleshooting

### Core deployed but healthcare wasn't

**Cause**: Only `force-app/core/` changed, not `force-app/healthcare/`.  
**Expected**: Core deploys to both orgs. Healthcare job runs but only the "Deploy Core" step executes.

### Both orgs get everything

**Cause**: `--source-dir` points to the wrong folder.  
**Fix**: Ensure each job deploys only its package folder, not all of `force-app/`.

### Secret not found

**Cause**: Secret name mismatch.  
**Fix**: Verify exact names: `SFDX_URL_HEALTHCARE`, `SFDX_URL_FINANCE`.

### deploy-healthcare skipped when it shouldn't be

**Cause**: `dorny/paths-filter` didn't detect changes.  
**Fix**: Verify the push included files under `force-app/healthcare/**` or `force-app/core/**`.

---

## Summary

| Component | Role |
|-----------|------|
| `dorny/paths-filter` | Detects which folders changed |
| `SFDX_URL_HEALTHCARE` | Auth secret for Org 1 |
| `SFDX_URL_FINANCE` | Auth secret for Org 2 |
| `deploy-healthcare` job | Deploys core + healthcare → Org 1 |
| `deploy-finance` job | Deploys core + finance → Org 2 |
| `sfdx-project.json` | Defines packages and dependencies |
| `validate.yml` | Validates all packages against one org before merge |

---

*End of Multi-Org Deployment Guide*
