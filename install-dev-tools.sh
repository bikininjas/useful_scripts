#!/bin/bash

# Définition des couleurs pour l'installation
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[INSTALL]${NC} Création du dossier scripts/..."
mkdir -p scripts

# 1. Génération de _utils.sh
cat << 'EOF' > scripts/_utils.sh
#!/bin/bash
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        log_error "La commande '$1' est requise mais absente."
        exit 1
    fi
}
EOF

# 2. Génération de check.sh
cat << 'EOF' > scripts/check.sh
#!/bin/bash
source ./scripts/_utils.sh
log_info "🔍 Quality Check..."

log_info "--- Backend (Ruff) ---"
cd backend || exit
ruff check . --fix && ruff format .
if [ $? -ne 0 ]; then log_error "Backend check failed"; exit 1; fi
cd ..

log_info "--- Frontend (Bun) ---"
cd frontend || exit
bun lint && bun tsc --noEmit
if [ $? -ne 0 ]; then log_error "Frontend check failed"; exit 1; fi
cd ..

log_success "Code Quality: OK ✅"
EOF

# 3. Génération de db-reset.sh
cat << 'EOF' > scripts/db-reset.sh
#!/bin/bash
source ./scripts/_utils.sh
log_info "🔄 Database Reset..."

check_cmd docker
docker compose down db
docker compose up -d db

log_info "Waiting for Postgres..."
until docker compose exec db pg_isready -U postgres; do sleep 1; done

log_info "Running Migrations..."
cd backend || exit
alembic upgrade head
cd ..

log_success "Database Ready ✅"
EOF

# 4. Génération de test.sh
cat << 'EOF' > scripts/test.sh
#!/bin/bash
source ./scripts/_utils.sh
TYPE=$1

if [ "$TYPE" != "front" ]; then
    log_info "🧪 Backend Tests..."
    cd backend || exit
    pytest --asyncio-mode=auto
    cd ..
fi

if [ "$TYPE" != "back" ]; then
    log_info "🧪 Frontend Tests..."
    cd frontend || exit
    bun run test
    cd ..
fi
EOF

# 5. Génération de bootstrap.sh
cat << 'EOF' > scripts/bootstrap.sh
#!/bin/bash
source ./scripts/_utils.sh
log_info "🚀 Bootstrap Project..."

# Backend
cd backend || exit
if [ ! -d "venv" ]; then python3 -m venv venv; fi
source venv/bin/activate
pip install -r requirements.txt
cd ..

# Frontend
cd frontend || exit
if [ ! -f "bun.lockb" ]; then bun install; fi
cd ..

# Env
if [ ! -f .env ]; then cp .env.example .env 2>/dev/null || touch .env; fi

log_success "Setup Complete! Run './scripts/db-reset.sh' next."
EOF

# Finalisation
echo -e "${BLUE}[INSTALL]${NC} Application des permissions..."
chmod +x scripts/*.sh

echo -e "${GREEN}[SUCCESS]${NC} Scripts installés dans ./scripts/"
echo -e "Voulez-vous lancer le bootstrap maintenant ? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    ./scripts/bootstrap.sh
fi
