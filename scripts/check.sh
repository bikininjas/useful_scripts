#!/bin/bash
source ./scripts/_utils.sh

log_info "Démarrage des vérifications de qualité de code..."

# --- Backend ---
log_info "Backend: Vérification avec Ruff..."
cd backend || exit

# Linting avec fix automatique
log_info "Backend: Ruff Check & Fix"
ruff check . --fix
if [ $? -ne 0 ]; then log_error "Ruff check a échoué"; exit 1; fi

# Formatting
log_info "Backend: Ruff Format"
ruff format .
if [ $? -ne 0 ]; then log_error "Ruff format a échoué"; exit 1; fi

cd ..

# --- Frontend ---
log_info "Frontend: Vérification avec Bun..."
cd frontend || exit

# Linting
log_info "Frontend: Bun Lint"
bun lint
if [ $? -ne 0 ]; then log_error "Bun lint a échoué"; exit 1; fi

# Type Checking (TypeScript)
log_info "Frontend: TypeScript Check"
bun tsc --noEmit
if [ $? -ne 0 ]; then log_error "Erreurs de types TypeScript détectées"; exit 1; fi

cd ..

log_success "Tout est propre ! Le code respecte les standards."
