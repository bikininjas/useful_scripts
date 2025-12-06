#!/bin/bash

# setup-scripts.sh
# Ce script génère les outils de CI/CD locaux pour un projet Python/FastAPI + Next.js

echo "📁 Création du dossier scripts/..."
mkdir -p scripts

# ---------------------------------------------------------
# 1. CI BACKEND LINT (100% RUFF)
# ---------------------------------------------------------
echo "Creating scripts/ci-backend-lint.sh..."
cat > scripts/ci-backend-lint.sh << 'EOF'
#!/bin/bash
set -e # Arrêter le script en cas d'erreur

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== [Backend] Running Ruff Format & Check ===${NC}"

cd backend

# 1. Formatage du code (équivalent de Black)
echo "1. Applying formatting..."
ruff format .

# 2. Linting avec corrections automatiques (imports, variables inutilisées, etc.)
echo "2. Checking and fixing linting issues..."
ruff check . --fix

echo -e "${GREEN}✅ Backend code is clean and formatted.${NC}"
EOF

# ---------------------------------------------------------
# 2. CI BACKEND TEST
# ---------------------------------------------------------
echo "Creating scripts/ci-backend-test.sh..."
cat > scripts/ci-backend-test.sh << 'EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== [Backend] Running Tests ===${NC}"

cd backend

# Vérifie si pytest est installé
if ! command -v pytest &> /dev/null; then
    echo "Error: pytest could not be found. Are you in your venv?"
    exit 1
fi

# Lance les tests
# Note: Assurez-vous que votre DB de test est accessible ou que vous utilisez docker exec si besoin
pytest

echo -e "${GREEN}✅ Backend tests passed.${NC}"
EOF

# ---------------------------------------------------------
# 3. CI FRONTEND LINT
# ---------------------------------------------------------
echo "Creating scripts/ci-frontend-lint.sh..."
cat > scripts/ci-frontend-lint.sh << 'EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== [Frontend] Running Lint & Type Check ===${NC}"

cd frontend

# Vérifie l'utilisation de Bun
if ! command -v bun &> /dev/null; then
    echo "Error: bun is required but not installed."
    exit 1
fi

echo "1. ESLint..."
bun run lint

echo "2. TypeScript Check..."
bun tsc --noEmit

echo -e "${GREEN}✅ Frontend code is clean.${NC}"
EOF

# ---------------------------------------------------------
# 4. CI GLOBAL (ALL)
# ---------------------------------------------------------
echo "Creating scripts/ci-all.sh..."
cat > scripts/ci-all.sh << 'EOF'
#!/bin/bash
set -e

# Ce script lance toute la suite de validation
# Utile avant de push sur git

./scripts/ci-backend-lint.sh
./scripts/ci-frontend-lint.sh
./scripts/ci-backend-test.sh

echo ""
echo "🎉 ALL CHECKS PASSED! YOU CAN PUSH. 🎉"
EOF

# ---------------------------------------------------------
# FINALISATION
# ---------------------------------------------------------

echo "🔐 Rendre les scripts exécutables..."
chmod +x scripts/*.sh

echo "✅ Terminé ! Vos scripts sont prêts dans le dossier scripts/ :"
ls -l scripts/
