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
if [ -t 0 ]; then read -r update_sys; else read -r update_sys < /dev/tty; fi

if [[ "$update_sys" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    log_info "Mise à jour du système..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl unzip git make
    log_success "Système à jour."
fi

# --- Check Python Version ---
if command -v python3 &>/dev/null; then
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 12) else 1)"; then
        log_success "$(python3 --version) détecté."
    else
        log_warn "Attention : $(python3 --version) détecté. Optimisé pour 3.12+."
    fi
else
    log_error "Python3 n'est pas installé."
    exit 1
fi

# --- Check Bun ---
if ! command -v bun &>/dev/null; then
    log_warn "Bun n'est pas installé."
    echo -e "${YELLOW}Voulez-vous installer Bun maintenant ? (y/n)${NC}"
    if [ -t 0 ]; then read -r install_bun; else read -r install_bun < /dev/tty; fi
    
    if [[ "$install_bun" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        curl -fsSL https://bun.sh/install | bash
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        log_success "Bun installé !"
    fi
else
    log_success "Bun détecté ($(bun --version))."
fi

# ==========================================
# 2. SCAFFOLDING (CREATION STRUCTURE)
# ==========================================
log_info "🏗️  Vérification / Création de la structure du projet..."

# Création des dossiers s'ils n'existent pas
mkdir -p scripts backend frontend database

# Création fichiers de base Backend
if [ ! -f "backend/requirements.txt" ]; then
    echo "# FastAPI deps" > backend/requirements.txt
    echo "fastapi" >> backend/requirements.txt
    echo "uvicorn" >> backend/requirements.txt
    echo "sqlalchemy" >> backend/requirements.txt
    echo "alembic" >> backend/requirements.txt
    echo "pydantic" >> backend/requirements.txt
    echo "python-dotenv" >> backend/requirements.txt
fi

# Création .gitkeep pour Frontend et Database (pour qu'ils soient commités même vides)
touch frontend/.gitkeep database/.gitkeep

# Gestion des variables d'environnement (.env)
if [ ! -f ".env.example" ]; then
    log_info "Création du template .env.example..."
    cat << 'EOF' > .env.example
# --- DATABASE ---
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=app_db
POSTGRES_HOST=db
POSTGRES_PORT=5432

# --- BACKEND ---
SECRET_KEY=change_me_super_secret_key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# --- FRONTEND ---
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF
fi

if [ ! -f ".env" ]; then
    log_info "Génération du fichier .env local..."
    cp .env.example .env
fi

# ==========================================
# 3. GENERATION DES SCRIPTS DE MAINTENANCE
# ==========================================
log_info "📂 Génération des scripts utilitaires dans ./scripts/..."

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
cd backend || exit
log_info "Backend: Ruff..."
ruff check . --fix && ruff format .
cd ../frontend || exit
log_info "Frontend: Bun Lint & TSC..."
bun lint && bun tsc --noEmit
cd ..
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
cd backend || exit
log_info "Alembic Migrations..."
alembic upgrade head
cd ..
log_success "Database Ready ✅"
EOF

# --- test.sh ---
cat << 'EOF' > scripts/test.sh
#!/bin/bash
source ./scripts/_utils.sh
TYPE=$1
if [ "$TYPE" != "front" ]; then
    log_info "🧪 Backend Tests..."
    cd backend || exit; pytest --asyncio-mode=auto; cd ..
fi
if [ "$TYPE" != "back" ]; then
    log_info "🧪 Frontend Tests..."
    cd frontend || exit; bun run test; cd ..
fi
EOF

# --- bootstrap.sh (Modifié pour forcer venv) ---
cat << 'EOF' > scripts/bootstrap.sh
#!/bin/bash
source ./scripts/_utils.sh
log_info "🚀 Bootstrap Project..."

# 1. Backend & Venv
cd backend || exit
if [ ! -d "venv" ]; then
    log_info "Création du virtual environment Python (venv)..."
    python3 -m venv venv
else
    log_info "Venv existant détecté."
fi

# Activation et Installation
source venv/bin/activate
log_info "Installation des dépendances Python (pip)..."
pip install --upgrade pip
if [ -f "requirements.txt" ]; then 
    pip install -r requirements.txt
else
    log_warn "Pas de requirements.txt trouvé dans backend/"
fi
cd ..

# 2. Frontend
cd frontend || exit
if [ -f "package.json" ]; then
    log_info "Installation des dépendances Frontend..."
    bun install
else
    log_warn "Dossier frontend vide (pas de package.json). Pense à lancer 'bun create next-app' ici."
fi
cd ..

log_success "Bootstrap terminé ! Venv créé dans backend/venv"
EOF

chmod +x scripts/*.sh
log_success "Scripts et structure générés."

# ==========================================
# 4. EXECUTION INITIALE
# ==========================================
echo -e "${YELLOW}Voulez-vous lancer le bootstrap (création venv & install) maintenant ? (y/n)${NC}"
if [ -t 0 ]; then read -r run_boot; else read -r run_boot < /dev/tty; fi

if [[ "$run_boot" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    ./scripts/bootstrap.sh
fi
