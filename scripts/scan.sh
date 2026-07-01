#!/usr/bin/env bash
# ============================================================
#  🔍 Local Security & Quality Scanner
#  Runs all open-source scanning tools locally (no Jenkins needed).
#
#  Usage:
#    ./scripts/scan.sh              # run ALL checks
#    ./scripts/scan.sh --quick      # skip Trivy image scan (fast)
#    ./scripts/scan.sh --list       # list available checks
#    ./scripts/scan.sh hadolint     # run only hadolint
#    ./scripts/scan.sh bandit       # run only bandit
#    ./scripts/scan.sh trivy-fs     # run only Trivy filesystem scan
#    ./scripts/scan.sh trivy-image  # run only Trivy image scan
#    ./scripts/scan.sh owasp        # run only OWASP DC
#    ./scripts/scan.sh sonar        # run only SonarQube scanner
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

banner()  { echo ""; echo "═══════════════════════════════════════════════"; echo "  $1"; echo "═══════════════════════════════════════════════"; }
pass()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail()   { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
skip()   { echo "  ⏭️  $1"; }
tool_exists() { command -v "$1" &>/dev/null; }

# ── Parse arguments ──────────────────────────────────────────
RUN_ALL=true
RUN_HADOLINT=false
RUN_BANDIT=false
RUN_RUFF_LINT=false
RUN_RUFF_FORMAT=false
RUN_MYPY=false
RUN_TRIVY_FS=false
RUN_TRIVY_IMAGE=false
RUN_OWASP=false
RUN_SONAR=false
QUICK=false

if [[ $# -eq 0 ]]; then
    RUN_ALL=true
elif [[ "$1" == "--list" ]]; then
    echo "Available checks:"
    echo "  hadolint      — Lint Dockerfiles"
    echo "  bandit        — Python security linting"
    echo "  ruff-lint     — Ruff Python linter (syntax, imports, naming)"
    echo "  ruff-format   — Ruff format check (Black-compatible)"
    echo "  mypy          — mypy static type checking"
    echo "  trivy-fs      — Trivy filesystem vulnerability scan"
    echo "  trivy-image   — Trivy container image scan (requires built images)"
    echo "  owasp         — OWASP Dependency-Check for Python deps"
    echo "  sonar         — SonarQube scanner (requires SonarQube server)"
    echo ""
    echo "Modes:"
    echo "  --quick       — Skip slow scans (Trivy image)"
    echo "  (no args)     — Run all checks"
    exit 0
elif [[ "$1" == "--quick" ]]; then
    RUN_ALL=true
    QUICK=true
else
    RUN_ALL=false
    for arg in "$@"; do
        case "$arg" in
            hadolint)    RUN_HADOLINT=true ;;
            bandit)      RUN_BANDIT=true ;;
            ruff-lint)   RUN_RUFF_LINT=true ;;
            ruff-format) RUN_RUFF_FORMAT=true ;;
            mypy)        RUN_MYPY=true ;;
            trivy-fs)    RUN_TRIVY_FS=true ;;
            trivy-image) RUN_TRIVY_IMAGE=true ;;
            owasp)       RUN_OWASP=true ;;
            sonar)       RUN_SONAR=true ;;
            --quick)     QUICK=true ;;
        esac
    done
fi

if $RUN_ALL; then
    RUN_HADOLINT=true
    RUN_BANDIT=true
    RUN_RUFF_LINT=true
    RUN_RUFF_FORMAT=true
    RUN_MYPY=true
    RUN_TRIVY_FS=true
    $QUICK || RUN_TRIVY_IMAGE=true
    RUN_OWASP=true
    # SonarQube requires a server — only run if explicitly requested
fi

echo "🔍 Starting security & quality scan..."
echo "   Tools: hadolint=$RUN_HADOLINT bandit=$RUN_BANDIT ruff-lint=$RUN_RUFF_LINT ruff-format=$RUN_RUFF_FORMAT mypy=$RUN_MYPY trivy-fs=$RUN_TRIVY_FS trivy-image=$RUN_TRIVY_IMAGE owasp=$RUN_OWASP"
echo ""

# ═════════════════════════════════════════════════════════════
#  1. Hadolint — Dockerfile linter
# ═════════════════════════════════════════════════════════════
if $RUN_HADOLINT; then
    banner "Hadolint — Dockerfile Lint"
    if tool_exists hadolint; then
        for df in backend/Dockerfile frontend/Dockerfile ansible/target-image/Dockerfile; do
            if [[ -f "$df" ]]; then
                echo "  → $df"
                hadolint -c .hadolint.yaml "$df" && pass "hadolint: $df" || fail "hadolint: $df"
            fi
        done
    elif tool_exists docker; then
        echo "  hadolint not installed — using Docker image..."
        for df in backend/Dockerfile frontend/Dockerfile ansible/target-image/Dockerfile; do
            if [[ -f "$df" ]]; then
                echo "  → $df"
                docker run --rm -v "$PWD:/work" -w /work hadolint/hadolint:latest \
                    hadolint -c .hadolint.yaml "$df" \
                    && pass "hadolint: $df" || fail "hadolint: $df"
            fi
        done
    else
        skip "hadolint not available — install with: brew install hadolint"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  2. Bandit — Python security linter
# ═════════════════════════════════════════════════════════════
if $RUN_BANDIT; then
    banner "Bandit — Python Security Lint"
    if tool_exists bandit; then
        bandit -r backend/ frontend/ -f json -o bandit-report.json 2>/dev/null \
            && pass "bandit: no high-severity issues" \
            || fail "bandit: issues found (see bandit-report.json)"
        # Also print a summary
        bandit -r backend/ frontend/ -q 2>/dev/null || true
    elif pip3 show bandit &>/dev/null; then
        python3 -m bandit -r backend/ frontend/ -q && pass "bandit: OK" || fail "bandit: issues found"
    else
        skip "bandit not installed — run: pip3 install bandit"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  3. Ruff — Python linter (syntax, imports, naming, unused code)
# ═════════════════════════════════════════════════════════════
if $RUN_RUFF_LINT; then
    banner "Ruff — Python Lint"
    if tool_exists ruff; then
        ruff check --config pyproject.toml backend/ frontend/ \
            && pass "ruff lint: no issues" \
            || fail "ruff lint: issues found (run 'ruff check --fix' to auto-fix)"
    elif tool_exists docker; then
        echo "  ruff not installed — using Docker image..."
        docker run --rm -v "$PWD:/work" -w /work \
            ghcr.io/astral-sh/ruff:latest check \
            --config /work/pyproject.toml \
            /work/backend/ /work/frontend/ \
            && pass "ruff lint: no issues" || fail "ruff lint: issues found"
    else
        skip "ruff not available — install with: pip3 install ruff"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  4. Ruff — Format check (Black-compatible formatter)
# ═════════════════════════════════════════════════════════════
if $RUN_RUFF_FORMAT; then
    banner "Ruff — Format Check"
    if tool_exists ruff; then
        ruff format --check --config pyproject.toml backend/ frontend/ \
            && pass "ruff format: style is correct" \
            || fail "ruff format: style issues (run 'ruff format' to fix)"
    elif tool_exists docker; then
        echo "  ruff not installed — using Docker image..."
        docker run --rm -v "$PWD:/work" -w /work \
            ghcr.io/astral-sh/ruff:latest format --check \
            --config /work/pyproject.toml \
            /work/backend/ /work/frontend/ \
            && pass "ruff format: OK" || fail "ruff format: issues found"
    else
        skip "ruff not available — install with: pip3 install ruff"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  5. mypy — Static type checking
# ═════════════════════════════════════════════════════════════
if $RUN_MYPY; then
    banner "mypy — Static Type Check"
    if tool_exists mypy; then
        mypy --config-file pyproject.toml backend/ frontend/ \
            && pass "mypy: no type errors" \
            || fail "mypy: type errors found"
    elif tool_exists docker; then
        echo "  mypy not installed — using Docker image..."
        docker run --rm -v "$PWD:/work" -w /work \
            python:3.11-slim bash -c "\
                pip install mypy -q && \
                cp /work/pyproject.toml . && \
                mypy --config-file pyproject.toml /work/backend/ /work/frontend/" \
            && pass "mypy: OK" || fail "mypy: type errors found"
    else
        skip "mypy not available — install with: pip3 install mypy"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  6. Trivy — Filesystem scan (Python deps, code, configs)
# ═════════════════════════════════════════════════════════════
if $RUN_TRIVY_FS; then
    banner "Trivy — Filesystem Vulnerability Scan"
    if tool_exists trivy; then
        trivy fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL \
            --ignorefile .trivyignore \
            -f json -o trivy-fs-report.json \
            ./backend ./frontend \
            && pass "trivy fs: no HIGH/CRITICAL vulnerabilities" \
            || fail "trivy fs: vulnerabilities found (see trivy-fs-report.json)"
        # Print summary to console
        trivy fs --scanners vuln --severity HIGH,CRITICAL ./backend ./frontend 2>/dev/null || true
    elif tool_exists docker; then
        echo "  trivy not installed — using Docker image..."
        docker run --rm -v "$PWD:/work" -w /work \
            aquasec/trivy:latest fs \
            --scanners vuln,secret,misconfig --severity HIGH,CRITICAL \
            --ignorefile /work/.trivyignore \
            -f json -o /work/trivy-fs-report.json \
            /work/backend /work/frontend \
            && pass "trivy fs: OK" || fail "trivy fs: issues found"
    else
        skip "trivy not available — install with: brew install trivy"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  7. Trivy — Container image scan (requires built images)
# ═════════════════════════════════════════════════════════════
if $RUN_TRIVY_IMAGE; then
    banner "Trivy — Container Image Scan"
    if ! tool_exists trivy && ! tool_exists docker; then
        skip "trivy not available"
    else
        for img in "student-backend:latest" "student-frontend:latest"; do
            if docker image inspect "$img" &>/dev/null 2>&1; then
                echo "  Scanning: $img"
                if tool_exists trivy; then
                    trivy image --severity HIGH,CRITICAL \
                        --ignorefile .trivyignore \
                        -f json -o "trivy-image-${img%%:*}-report.json" \
                        "$img" \
                        && pass "trivy image $img: OK" \
                        || fail "trivy image $img: vulnerabilities found"
                    trivy image --severity HIGH,CRITICAL "$img" 2>/dev/null || true
                else
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        -v "$PWD:/work" aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL \
                        --ignorefile /work/.trivyignore \
                        -f json -o "/work/trivy-image-${img%%:*}-report.json" \
                        "$img" \
                        && pass "trivy image $img: OK" \
                        || fail "trivy image $img: issues found"
                fi
            else
                skip "trivy image: $img not built — run 'docker build -t $img ./${img%%:*}' first"
            fi
        done
    fi
fi

# ═════════════════════════════════════════════════════════════
#  8. OWASP Dependency-Check — Python dependency vulns
# ═════════════════════════════════════════════════════════════
if $RUN_OWASP; then
    banner "OWASP Dependency-Check — Python Dependencies"
    if tool_exists dependency-check; then
        dependency-check --scan ./backend/requirements.txt,./frontend/requirements.txt \
            --format JSON --out ./dependency-check-report.json \
            --suppress .trivyignore \
            && pass "OWASP DC: scan complete" \
            || fail "OWASP DC: vulnerabilities found (see dependency-check-report.json)"
    elif tool_exists docker; then
        echo "  dependency-check not installed — using Docker image..."
        mkdir -p owasp-report
        docker run --rm -v "$PWD:/src" \
            owasp/dependency-check:latest \
            --scan /src/backend/requirements.txt,/src/frontend/requirements.txt \
            --format JSON \
            --out /src/owasp-report \
            --project "Student App" \
            && pass "OWASP DC: scan complete" \
            || fail "OWASP DC: issues found"
    else
        skip "OWASP Dependency-Check not available"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  9. SonarQube Scanner (requires a running SonarQube server)
# ═════════════════════════════════════════════════════════════
if $RUN_SONAR; then
    banner "SonarQube — Code Quality Scan"
    if [[ -f "sonar-project.properties" ]]; then
        if tool_exists sonar-scanner; then
            sonar-scanner \
                -Dsonar.host.url="${SONAR_HOST_URL:-http://localhost:9000}" \
                -Dsonar.login="${SONAR_TOKEN:-}" \
                -Dproject.settings=sonar-project.properties \
                && pass "SonarQube: analysis complete" \
                || fail "SonarQube: analysis failed"
        elif tool_exists docker; then
            echo "  sonar-scanner not installed — using Docker image..."
            docker run --rm \
                -v "$PWD:/usr/src" \
                -e SONAR_HOST_URL="${SONAR_HOST_URL:-http://host.docker.internal:9000}" \
                -e SONAR_TOKEN="${SONAR_TOKEN:-}" \
                sonarsource/sonar-scanner-cli:latest \
                -Dsonar.projectBaseDir=/usr/src \
                && pass "SonarQube: analysis complete" \
                || fail "SonarQube: analysis failed"
        else
            skip "SonarQube scanner not available"
        fi
    else
        skip "sonar-project.properties not found"
    fi
fi

# ═════════════════════════════════════════════════════════════
#  Summary
# ═════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════"
echo "  Scan Complete:  ✅ $PASS passed  |  ❌ $FAIL failed"
echo "═══════════════════════════════════════════════"
echo ""
echo "Reports generated:"
ls -lh bandit-report.json trivy-*-report.json owasp-report/ dependency-check-report.json 2>/dev/null || echo "  (none — run full scan to generate reports)"
echo ""

exit $FAIL
