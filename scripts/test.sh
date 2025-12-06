#!/bin/bash
source ./scripts/_utils.sh

TYPE=$1 # Optionnel: 'back', 'front' ou vide pour tout

run_back() {
    log_info "🧪 Lancement des tests Backend (Pytest Asyncio)..."
    cd backend || exit
    # Force le mode async comme demandé dans les instructions
    pytest --asyncio-mode=auto
    if [ $? -ne 0 ]; then log_error "Tests Backend échoués"; exit 1; fi
    cd ..
}

run_front() {
    log_info "🧪 Lancement des tests Frontend (Vitest)..."
    cd frontend || exit
    bun run test
    if [ $? -ne 0 ]; then log_error "Tests Frontend échoués"; exit 1; fi
    cd ..
}

if [ "$TYPE" == "back" ]; then
    run_back
elif [ "$TYPE" == "front" ]; then
    run_front
else
    run_back
    run_front
fi

log_success "Tous les tests sont passés avec succès."
