@echo off
echo 🚀 Déploiement de Claude Serverless Chat
echo ========================================

REM Vérifications des prérequis
echo 📋 Vérification des prérequis...

where terraform >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Terraform n'est pas installé
    exit /b 1
)

where aws >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ AWS CLI n'est pas installé
    exit /b 1
)

where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Python n'est pas installé
    exit /b 1
)

where pip >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ pip n'est pas installé
    exit /b 1
)

echo ✅ Prérequis vérifiés

REM Variables
if not defined AWS_REGION set AWS_REGION=eu-west-1
if not defined ENVIRONMENT set ENVIRONMENT=dev
set PROJECT_NAME=claude-serverless

echo 🏗️  Configuration:
echo    - Region: %AWS_REGION%
echo    - Environment: %ENVIRONMENT%
echo    - Project: %PROJECT_NAME%

REM 1. Installation des dépendances frontend
echo 📦 Installation des dépendances...
call npm run install:all

REM 2. Build du backend Python
echo 🔨 Build du backend Python...
cd backend-python
call build.bat
cd ..

REM 3. Déploiement de l'infrastructure
echo 🏗️  Déploiement de l'infrastructure Terraform...
cd infrastructure
terraform init
terraform plan
echo ⚠️  Voulez-vous continuer avec le déploiement? (y/N)
set /p CONFIRM=
if /i "%CONFIRM%"=="y" (
    terraform apply -auto-approve
    
    REM Récupération des outputs Terraform
    for /f %%i in ('terraform output -raw cognito_user_pool_id') do set USER_POOL_ID=%%i
    for /f %%i in ('terraform output -raw cognito_user_pool_client_id') do set CLIENT_ID=%%i
    for /f %%i in ('terraform output -raw api_gateway_url') do set API_URL=%%i
    for /f %%i in ('terraform output -raw cloudfront_domain_name') do set CLOUDFRONT_URL=%%i
    for /f %%i in ('terraform output -raw frontend_bucket') do set FRONTEND_BUCKET=%%i
    
    echo ✅ Infrastructure déployée
    echo 📝 Configuration AWS:
    echo    - User Pool ID: %USER_POOL_ID%
    echo    - Client ID: %CLIENT_ID%
    echo    - API URL: %API_URL%
    echo    - CloudFront URL: https://%CLOUDFRONT_URL%
) else (
    echo ❌ Déploiement annulé
    exit /b 1
)
cd ..

REM 4. Mise à jour de la configuration frontend
echo ⚙️  Mise à jour de la configuration frontend...
(
echo export const AWS_CONFIG = {
echo   region: '%AWS_REGION%',
echo   userPoolId: '%USER_POOL_ID%',
echo   clientId: '%CLIENT_ID%',
echo   apiUrl: '%API_URL%',
echo };
echo.
echo export default AWS_CONFIG;
) > frontend\src\config\aws.ts

REM Mise à jour de la configuration des domaines
(
echo // Configuration des domaines autorisés
echo export const ALLOWED_ORIGINS = [
echo   'https://claude-serverless.daveo-dev.fr',
echo   'https://%CLOUDFRONT_URL%',
echo ] as const;
echo.
echo // Détection automatique du domaine courant
echo export const getCurrentDomain = ^(^): string =^> {
echo   if ^(typeof window !== 'undefined'^) {
echo     return window.location.origin;
echo   }
echo   return 'http://localhost:3000';
echo };
echo.
echo // Vérification si le domaine courant est autorisé
echo export const isAllowedOrigin = ^(origin?: string^): boolean =^> {
echo   const currentOrigin = origin ^|^| getCurrentDomain^(^);
echo   
echo   return ALLOWED_ORIGINS.some^(allowedOrigin =^> 
echo     currentOrigin === allowedOrigin ^|^|
echo     currentOrigin.endsWith^('.cloudfront.net'^) ^|^|
echo     currentOrigin.includes^('localhost'^)
echo   ^);
echo };
echo.
echo export default {
echo   ALLOWED_ORIGINS,
echo   getCurrentDomain,
echo   isAllowedOrigin,
echo };
) > frontend\src\config\domains.ts

REM 5. Build et déploiement du frontend
echo 🎨 Build et déploiement du frontend...
cd frontend
call npm run build

REM Upload vers S3
echo 📤 Upload vers S3...
aws s3 sync dist/ s3://%FRONTEND_BUCKET% --delete --region %AWS_REGION%

REM Invalidation CloudFront
cd ..\infrastructure
for /f %%i in ('terraform output -raw cloudfront_distribution_id') do set DISTRIBUTION_ID=%%i
cd ..\frontend
echo 🔄 Invalidation CloudFront...
aws cloudfront create-invalidation --distribution-id %DISTRIBUTION_ID% --paths "/*" --region %AWS_REGION%

cd ..

echo.
echo 🎉 Déploiement terminé avec succès!
echo 🌐 URL de l'application: https://%CLOUDFRONT_URL%
echo.
echo 📚 Prochaines étapes:
echo    1. Créer des utilisateurs dans Cognito
echo    2. Configurer les permissions Bedrock si nécessaire
echo    3. Tester l'application