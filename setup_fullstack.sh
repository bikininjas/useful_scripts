#!/bin/bash

# ==========================================
# CONFIGURATION & COLORS
# ==========================================
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==========================================
# 1. SYSTEM HEALTH & UPDATES
# ==========================================
log_info "🔍 Vérification de l'environnement système..."

# --- Mise à jour Système ---
echo -e "${YELLOW}Voulez-vous mettre à jour les paquets système (apt update & upgrade) ? (y/n)${NC}"
read -r update_sys
if [[ "$update_sys" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    log_info "Mise à jour du système (nécessite sudo)..."
    sudo apt update && sudo apt upgrade -y
    # On installe les outils de base
    sudo apt install -y curl unzip git make
    log_success "Système à jour."
fi

# --- Check Python Version (Méthode Robuste sans 'bc') ---
if command -v python3 &>/dev/null; then
    # On utilise python lui-même pour vérifier s'il est >= 3.12
    # Exit code 0 = True, 1 = False
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 12) else 1)"; then
        PY_VERSION=$(python3 --version)
        log_success "$PY_VERSION détecté (Compatible)."
    else
        PY_VERSION=$(python3 --version)
        log_warn "Attention : $PY_VERSION détecté. Ce projet est optimisé pour Python 3.12+."
    fi
else
    log_error "Python3 n'est pas installé."
    exit 1
fi

# --- Check Bun (Frontend) ---
if ! command -v bun &>/dev/null; then
    log_warn "Bun n'est pas installé."
    echo -e "${YELLOW}Voulez-vous installer Bun maintenant ? (y/n)${NC}"
    read -r install_bun
    if [[ "$install_bun" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        curl -fsSL https://bun.sh/install | bash
        # Configuration immédiate du path pour ce script
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        log_success "Bun installé !"
    fi
else
    log_success "Bun détecté ($(bun --version))."
fi

# ==========================================
# 2. GENERATION DES SCRIPTS PROJET
# ==========================================
log_info "📂 Génération des scripts de dev dans ./scripts/..."
mkdir -p scripts

# --- _utils.sh ---
cat << 'EOF' > scripts/_utils.sh
#!/bin/bash
GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
check_cmd() { if ! command -v "$1" &> /dev/null; then log_error "Commande '$1' manquante."; exit 1; fi; }
EOF

# --- check.sh ---
cat << 'EOF' > scripts/check.sh
#!/bin/bash
source ./scripts/_utils.sh
log_info "🔍 Quality Check..."
if [ -d "backend" ]; then
    cd backend || exit
    log_info "Backend: Ruff..."
    ruff check . --fix && ruff format .
    cd ..
fi
if [ -d "frontend" ]; then
    cd frontend || exit
    log_info "Frontend: Bun Lint & TSC..."
    bun lint && bun tsc --noEmit
    cd ..
fi
log_success "Quality Check OK ✅"
EOF

# --- db-reset.sh ---
cat << 'EOF' > scripts/db-reset.sh
#!/bin/bash
source ./scripts/_utils.sh
log_info "🔄 Database Reset..."
check_cmd docker
docker compose down db
docker compose up -d db
log_info "Waiting for Postgres..."
until docker compose exec db pg_isready -U postgres; do sleep 1; done
if [ -d "backend" ]; then
    cd backend || exit
    log_info "Alembic Migrations..."
    alembic upgrade head
    cd ..
fi
log_success "Database Ready ✅"
EOF

# --- test.sh ---
cat << 'EOF' > scripts/test.sh
#!/bin/bash
source ./scripts/_utils.sh
TYPE=$1
if [ "$TYPE" != "front" ] && [ -d "backend" ]; then
    log_info "🧪 Backend Tests..."
    cd backend || exit; pytest --asyncio-mode=auto; cd ..
fi
if [ "$TYPE" != "back" ] && [ -d "frontend" ]; then
    log_info "🧪 Frontend Tests..."
    cd frontend || exit; bun run test; cd ..
fi
EOF

# --- bootstrap.sh ---
cat << 'EOF' > scripts/bootstrap.sh
#!/bin/bash
source ./scripts/_utils.sh
log_info "🚀 Bootstrap Project..."

# Setup Backend
if [ -d "backend" ]; then
    cd backend || exit
    if [ ! -d "venv" ]; then
        log_info "Création du virtual environment Python (venv)..."
        python3 -m venv venv
    fi
    source venv/bin/activate
    log_info "Installation des dépendances Python..."
    pip install --upgrade pip
    if [ -f "requirements.txt" ]; then pip install -r requirements.txt; fi
    cd ..
fi

# Setup Frontend
if [ -d "frontend" ]; then
    cd frontend || exit
    log_info "Installation des dépendances Frontend..."
    bun install
    cd ..
fi

# Env
if [ ! -f .env ]; then cp .env.example .env 2>/dev/null || touch .env; fi

log_success "Bootstrap terminé ! Le venv est dans backend/venv"
EOF

chmod +x scripts/*.sh
log_success "Scripts générés."

# ==========================================
# 3. EXECUTION INITIALE
# ==========================================
echo -e "${YELLOW}Voulez-vous lancer le bootstrap (install dependencies & venv) maintenant ? (y/n)${NC}"
read -r run_boot
if [[ "$run_boot" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    ./scripts/bootstrap.sh
fi
