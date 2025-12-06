#!/bin/bash
source ./scripts/_utils.sh

log_info "Initialisation du projet Full Stack..."

# --- Backend Setup ---
log_info "📦 Setup Backend (Python)..."
cd backend || exit

if [ ! -d "venv" ]; then
    log_warn "Aucun venv trouvé, création..."
    python3 -m venv venv
fi

source venv/bin/activate
log_info "Installation des dépendances Python..."
pip install -r requirements.txt
# Ou si tu utilises poetry: poetry install

cd ..

# --- Frontend Setup ---
log_info "📦 Setup Frontend (Bun)..."
check_cmd bun
cd frontend || exit

log_info "Installation des dépendances JS..."
bun install

cd ..

# --- Environment ---
if [ ! -f .env ]; then
    log_warn "Fichier .env manquant. Copie de .env.example..."
    cp .env.example .env 2>/dev/null || touch .env
fi

log_success "Setup terminé ! Tu peux lancer :"
log_info "  > ./scripts/db-reset.sh (pour la DB)"
log_info "  > docker compose up (pour lancer l'app)"
