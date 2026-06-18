# Justfile for ArgoCD GitOps Infrastructure
# Run `just` or `just --list` to see all available recipes

set shell := ["bash", "-euo", "pipefail", "-c"]

# Project root
root := justfile_directory()

# Default kubeconfig for hub cluster
kubeconfig := env('KUBECONFIG', env_var_or_default('HOME', '') + '/.kube/aks-rg-hypera-cafehyna-hub-config')

# ArgoCD server URL
argocd_server := env('ARGOCD_SERVER', 'argocd.cafehyna.com.br')

# ─── Default ───────────────────────────────────────────────

# List all available recipes
default:
    @just --list --unsorted

# ─── Validation ────────────────────────────────────────────

# Run ALL validation checks
[group('validation')]
validate: validate-applicationsets validate-k8s validate-kustomize validate-helm validate-multi-source validate-kustomization-coverage validate-deprecated validate-spot
    @echo "All validations passed."

# Validate ArgoCD ApplicationSet YAML syntax and schema
[group('validation')]
validate-applicationsets:
    ./scripts/validate-applicationsets.sh

# Validate Kubernetes manifests
[group('validation')]
validate-k8s:
    ./scripts/validate-k8s-manifests.sh

# Validate Kustomize overlays build successfully
[group('validation')]
validate-kustomize:
    ./scripts/validate-kustomize.sh

# Validate Helm chart values
[group('validation')]
validate-helm:
    ./scripts/validate-helm-values.sh

# Validate multi-source repository references
[group('validation')]
validate-multi-source:
    ./scripts/validate-multi-source.sh

# Check ApplicationSet kustomization coverage
[group('validation')]
validate-kustomization-coverage:
    ./scripts/validate-kustomization-coverage.sh

# Detect deprecated ApplicationSet patterns
[group('validation')]
validate-deprecated:
    ./scripts/check-deprecated-patterns.sh

# Check spot instance tolerations (dev environments)
[group('validation')]
validate-spot:
    ./scripts/check-spot-tolerations.sh

# ─── Linting ──────────────────────────────────────────────

# Run all linters
[group('linting')]
lint: lint-yaml lint-shell
    @echo "All linting passed."

# Lint YAML files with yamllint
[group('linting')]
lint-yaml:
    yamllint -c .yamllint .

# Lint Markdown files
[group('linting')]
lint-markdown:
    npx markdownlint-cli2 "**/*.md" "#node_modules" "#_bmad" "#docs"

# Lint shell scripts with shellcheck
[group('linting')]
lint-shell:
    shellcheck scripts/*.sh

# Validate JSON files
[group('linting')]
lint-json:
    pre-commit run check-json --all-files

# ─── Security ─────────────────────────────────────────────

# Run Trivy vulnerability scan on YAML files
[group('security')]
security-scan:
    ./scripts/trivy-scan.sh

# Detect accidentally committed private keys
[group('security')]
security-detect-secrets:
    pre-commit run detect-private-key --all-files

# ─── Pre-commit ───────────────────────────────────────────

# Run all pre-commit hooks against all files
[group('pre-commit')]
pre-commit:
    pre-commit run --all-files

# Install pre-commit hooks (including commit-msg)
[group('pre-commit')]
pre-commit-install:
    pre-commit install && pre-commit install --hook-type commit-msg

# Update pre-commit hook versions
[group('pre-commit')]
pre-commit-update:
    pre-commit autoupdate

# ─── ArgoCD Operations (read-only) ────────────────────────

# Login to ArgoCD server
[group('argocd')]
argocd-login:
    argocd login {{ argocd_server }} --sso

# List all ArgoCD Applications
[group('argocd')]
argocd-apps:
    kubectl --kubeconfig {{ kubeconfig }} get applications -n argocd

# List all ArgoCD ApplicationSets
[group('argocd')]
argocd-appsets:
    kubectl --kubeconfig {{ kubeconfig }} get applicationsets -n argocd

# Show sync status of all ArgoCD applications
[group('argocd')]
argocd-sync-status:
    kubectl --kubeconfig {{ kubeconfig }} get applications -n argocd -o wide

# Show health and sync details for a specific app
[group('argocd')]
argocd-app-detail name:
    kubectl --kubeconfig {{ kubeconfig }} describe application {{ name }} -n argocd

# Port-forward ArgoCD UI to localhost
[group('argocd')]
argocd-port-forward:
    ./scripts/argocd-port-forward.sh

# Port-forward ArgoCD metrics endpoint
[group('argocd')]
argocd-metrics:
    ./scripts/argocd-metrics-port-forward.sh

# ─── Cluster Operations ───────────────────────────────────

# List configured ArgoCD cluster definitions
[group('cluster')]
clusters:
    @ls infra-team/argocd-clusters/

# Connect to AKS cluster via Azure Bastion
[group('cluster')]
connect-bastion:
    ./scripts/connect-aks-via-bastion.sh

# Open kubectl tunnel through Azure Bastion
[group('cluster')]
bastion-tunnel:
    ./scripts/bastion-tunnel-kubectl.sh

# Verify Azure access and permissions
[group('cluster')]
check-azure-access:
    ./scripts/check-azure-access.sh

# ─── BMD Validation ───────────────────────────────────────

# Run all BMD-method validations
[group('bmd')]
bmd-validate: bmd-structure bmd-dependencies bmd-environments bmd-documentation
    @echo "All BMD validations passed."

# Validate repository structure against BMD standards
[group('bmd')]
bmd-structure:
    ./scripts/bmd-validate-structure.sh

# Check service dependency declarations
[group('bmd')]
bmd-dependencies:
    ./scripts/bmd-check-dependencies.sh

# Validate environment configurations
[group('bmd')]
bmd-environments:
    ./scripts/bmd-validate-environments.sh

# Check documentation completeness
[group('bmd')]
bmd-documentation:
    ./scripts/bmd-check-documentation.sh

# ─── Testing & Diagnostics ────────────────────────────────

# Test pre-commit hook setup
[group('testing')]
test-precommit:
    ./scripts/test-precommit.sh

# Test RBAC permissions configuration
[group('testing')]
test-rbac:
    ./scripts/test-rbac-permissions.sh

# Test monitoring alert rules
[group('testing')]
test-monitoring:
    ./scripts/test-monitoring-alerts.sh

# Test LGTM stack integration
[group('testing')]
test-lgtm:
    ./scripts/test-lgtm-integration.sh

# Run diagnostic checks
[group('testing')]
diagnose:
    ./scripts/run-diagnostic.sh

# ─── Git Workflow ──────────────────────────────────────────

# Show git working tree status
[group('git')]
status:
    git status

# Show unstaged changes
[group('git')]
diff:
    git diff

# Show recent commit history
[group('git')]
log count='20':
    git log --oneline -{{ count }}

# ─── ApplicationSet Management ─────────────────────────────

# List all ApplicationSet definition files
[group('appsets')]
appsets:
    @ls infra-team/applicationset/*.yaml | sed 's|.*/||; s|\.yaml||' | sort

# Show a specific ApplicationSet definition
[group('appsets')]
appset-show name:
    @cat infra-team/applicationset/{{ name }}.yaml

# Show the active ApplicationSet kustomization
[group('appsets')]
appset-kustomization:
    @cat infra-team/applicationset/kustomization.yaml

# Count ApplicationSets by status (in kustomization vs total)
[group('appsets')]
appset-coverage:
    @echo "Total ApplicationSet files:" && ls infra-team/applicationset/*.yaml | grep -v kustomization | grep -v README | wc -l | tr -d ' '
    @echo "In kustomization.yaml:" && grep -c '\.yaml' infra-team/applicationset/kustomization.yaml || echo "0"

# Validate a specific ApplicationSet against the cluster (dry-run)
[group('appsets')]
appset-dry-run name:
    kubectl -n argocd \
      --kubeconfig {{ kubeconfig }} \
      apply -f infra-team/applicationset/{{ name }}.yaml \
      --dry-run=client --validate=true

# Validate ALL ApplicationSet files against the cluster (dry-run)
[group('appsets')]
appset-dry-run-all:
    @for f in infra-team/applicationset/*.yaml; do \
      [ "$(basename "$f")" = "kustomization.yaml" ] && continue; \
      [ "$(basename "$f")" = "README.yaml" ] && continue; \
      echo "Validating $f..."; \
      kubectl -n argocd \
        --kubeconfig {{ kubeconfig }} \
        apply -f "$f" \
        --dry-run=client --validate=true; \
    done

# Apply a specific ApplicationSet to the cluster
[group('appsets')]
appset-apply name:
    kubectl -n argocd \
      --kubeconfig {{ kubeconfig }} \
      apply -f infra-team/applicationset/{{ name }}.yaml

# ─── Documentation ─────────────────────────────────────────

# List all documentation files
[group('docs')]
docs:
    @find docs/ -name '*.md' | sort

# Display a specific documentation file
[group('docs')]
doc name:
    @cat docs/{{ name }}

# ─── Utilities ────────────────────────────────────────────

# Show current public IP address
[group('utils')]
pip:
    @curl -s ifconfig.me
