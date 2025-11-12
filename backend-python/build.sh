#!/bin/bash

# Script de build pour les Lambda functions Python

set -e

BACKEND_DIR="$(dirname "$0")"
DIST_DIR="${BACKEND_DIR}/dist"
LAYERS_DIR="${BACKEND_DIR}/layers"

echo "🚀 Build des Lambda functions Python..."

# Créer les dossiers de distribution
mkdir -p "${DIST_DIR}"
mkdir -p "${LAYERS_DIR}"

# Nettoyer les anciens builds
rm -rf "${DIST_DIR}"/*.zip
rm -rf "${LAYERS_DIR}"/*.zip

echo "📦 Création du layer avec les dépendances..."

# Créer un dossier temporaire pour le layer dans le répertoire de travail
LAYER_TEMP="${BACKEND_DIR}/temp_layer"
LAYER_PYTHON_DIR="${LAYER_TEMP}/python"
mkdir -p "${LAYER_PYTHON_DIR}"

# Installer les dépendances dans le layer
pip install -r "${BACKEND_DIR}/requirements.txt" -t "${LAYER_PYTHON_DIR}"

# Créer le zip du layer
cd "${LAYER_TEMP}"
zip -r "../layers/dependencies.zip" python/
cd "${BACKEND_DIR}"

# Nettoyer le dossier temporaire
rm -rf "${LAYER_TEMP}"

echo "📦 Build de la fonction chat-handler..."

# Créer le package chat-handler
CHAT_TEMP="${BACKEND_DIR}/temp_chat"
mkdir -p "${CHAT_TEMP}"
cp -r "${BACKEND_DIR}/shared" "${CHAT_TEMP}/"
cp -r "${BACKEND_DIR}/chat" "${CHAT_TEMP}/"

# Créer le zip
cd "${CHAT_TEMP}"
zip -r "../dist/chat-handler.zip" . -x "*.pyc" "*/__pycache__/*" "*.git*"
cd "${BACKEND_DIR}"

# Nettoyer
rm -rf "${CHAT_TEMP}"

echo "📦 Build de la fonction file-processor..."

# Créer le package file-processor
FILE_TEMP="${BACKEND_DIR}/temp_file"
mkdir -p "${FILE_TEMP}"
cp -r "${BACKEND_DIR}/shared" "${FILE_TEMP}/"
cp -r "${BACKEND_DIR}/file_processor" "${FILE_TEMP}/"

# Créer le zip
cd "${FILE_TEMP}"
zip -r "../dist/file-processor.zip" . -x "*.pyc" "*/__pycache__/*" "*.git*"
cd "${BACKEND_DIR}"

# Nettoyer
rm -rf "${FILE_TEMP}"

echo "✅ Build terminé!"
echo "📁 Fichiers générés:"
echo "  - ${LAYERS_DIR}/dependencies.zip"
echo "  - ${DIST_DIR}/chat-handler.zip"
echo "  - ${DIST_DIR}/file-processor.zip"