@echo off
REM Script de build pour les Lambda functions Python sur Windows

setlocal enabledelayedexpansion

set BACKEND_DIR=%~dp0
set BACKEND_DIR=%BACKEND_DIR:~0,-1%
set DIST_DIR=%BACKEND_DIR%\dist
set LAYERS_DIR=%BACKEND_DIR%\layers

echo 🚀 Build des Lambda functions Python...

REM Créer les dossiers de distribution
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
if not exist "%LAYERS_DIR%" mkdir "%LAYERS_DIR%"

REM Nettoyer les anciens builds
del /Q "%DIST_DIR%\*.zip" 2>nul
del /Q "%LAYERS_DIR%\*.zip" 2>nul

echo 📦 Création du layer avec les dépendances...

REM Créer un dossier temporaire pour le layer
set LAYER_TEMP=%TEMP%\lambda-layer-%RANDOM%
mkdir "%LAYER_TEMP%\python"

REM Installer les dépendances dans le layer
pip install -r "%BACKEND_DIR%\requirements.txt" -t "%LAYER_TEMP%\python" --no-deps

REM Créer le zip du layer
cd /d "%LAYER_TEMP%"
powershell -Command "Compress-Archive -Path 'python' -DestinationPath '%LAYERS_DIR%\dependencies.zip' -Force"
cd /d "%BACKEND_DIR%"

REM Nettoyer le dossier temporaire
rmdir /S /Q "%LAYER_TEMP%"

echo 📦 Build de la fonction chat-handler...

REM Créer le package chat-handler
set CHAT_TEMP=%TEMP%\chat-handler-%RANDOM%
mkdir "%CHAT_TEMP%"
xcopy /S /E /Q "%BACKEND_DIR%\shared" "%CHAT_TEMP%\shared\"
xcopy /S /E /Q "%BACKEND_DIR%\chat" "%CHAT_TEMP%\chat\"

REM Créer le zip
cd /d "%CHAT_TEMP%"
powershell -Command "Get-ChildItem -Path '.' -Recurse | Where-Object {!$_.PSIsContainer -and $_.Name -notmatch '\.pyc$|__pycache__|\.git'} | Compress-Archive -DestinationPath '%DIST_DIR%\chat-handler.zip' -Force"
cd /d "%BACKEND_DIR%"

REM Nettoyer
rmdir /S /Q "%CHAT_TEMP%"

echo 📦 Build de la fonction file-processor...

REM Créer le package file-processor
set FILE_TEMP=%TEMP%\file-processor-%RANDOM%
mkdir "%FILE_TEMP%"
xcopy /S /E /Q "%BACKEND_DIR%\shared" "%FILE_TEMP%\shared\"
xcopy /S /E /Q "%BACKEND_DIR%\file_processor" "%FILE_TEMP%\file_processor\"

REM Créer le zip
cd /d "%FILE_TEMP%"
powershell -Command "Get-ChildItem -Path '.' -Recurse | Where-Object {!$_.PSIsContainer -and $_.Name -notmatch '\.pyc$|__pycache__|\.git'} | Compress-Archive -DestinationPath '%DIST_DIR%\file-processor.zip' -Force"
cd /d "%BACKEND_DIR%"

REM Nettoyer
rmdir /S /Q "%FILE_TEMP%"

echo ✅ Build terminé!
echo 📁 Fichiers générés:
echo   - %LAYERS_DIR%\dependencies.zip
echo   - %DIST_DIR%\chat-handler.zip
echo   - %DIST_DIR%\file-processor.zip

pause