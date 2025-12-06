#!/bin/bash
source ./scripts/_utils.sh

log_info "Réinitialisation de l'environnement Base de Données..."

# Vérifier Docker
check_cmd docker

# 1. Redémarrer le conteneur DB
log_info "Redémarrage du service 'db' via Docker Compose..."
docker compose down db
docker compose up -d db

# 2. Attendre que Postgres soit prêt
log_info "Attente de la disponibilité de Postgres..."
until docker compose exec db pg_isready -U postgres; do
  echo -n "."
  sleep 1
done
echo ""
log_success "Postgres est prêt !"

# 3. Migrations Alembic
log_info "Application des migrations Alembic..."
cd backend || exit
# On assume que l'environnement virtuel est activé ou géré par poetry/pdm, 
# sinon on appelle via 'poetry run' ou './venv/bin/alembic'
alembic upgrade head

if [ $? -eq 0 ]; then
    log_success "Base de données à jour (Alembic Head)."
else
    log_error "Échec des migrations Alembic."
    exit 1
fi

# (Optionnel) Script de seed
# log_info "Population de la base de données (Seed)..."
# python -m app.initial_data
