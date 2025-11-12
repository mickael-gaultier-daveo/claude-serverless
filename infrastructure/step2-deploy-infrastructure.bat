@echo off
echo 🚀 ÉTAPE 2 : Déploiement de l'infrastructure complète
echo =================================================

cd /d "%~dp0"

REM Vérification des paramètres
if "%1"=="" (
    if exist ".ssl-certificate-arn" (
        set /p SSL_CERT_ARN=<.ssl-certificate-arn
        echo 📋 ARN du certificat trouvé : !SSL_CERT_ARN!
    ) else (
        echo ❌ Erreur : ARN du certificat SSL requis
        echo Usage : %0 ^<SSL_CERTIFICATE_ARN^>
        echo Ou exécutez d'abord step1-deploy-ssl.bat
        pause
        exit /b 1
    )
) else (
    set SSL_CERT_ARN=%1
)

REM Variables
set PROJECT_NAME=claude-serverless
set ENVIRONMENT=prod
set REGION=eu-west-3

echo 🏗️  Configuration :
echo    - Projet : %PROJECT_NAME%
echo    - Environnement : %ENVIRONMENT%
echo    - Région : %REGION%
echo    - Certificat SSL : %SSL_CERT_ARN%
echo.

REM Vérifications
where terraform >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Terraform n'est pas installé
    pause
    exit /b 1
)

where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Python n'est pas installé
    pause
    exit /b 1
)

echo ✅ Prérequis vérifiés
echo.

REM 1. Installation des dépendances frontend
echo 📦 Installation des dépendances frontend...
cd ..
call npm install --prefix frontend
cd infrastructure

REM 2. Build du backend Python
echo 🔨 Build du backend Python...
cd ..\backend-python
call build.bat
cd ..\infrastructure

REM 3. Déploiement de l'infrastructure
echo 🏗️  Déploiement de l'infrastructure Terraform...

terraform init

REM Planification
terraform plan -var="ssl_certificate_arn=%SSL_CERT_ARN%"

echo.
echo ⚠️  Voulez-vous continuer avec le déploiement? (y/N)
set /p CONFIRM=

if /i "%CONFIRM%"=="y" (
    REM Apply
    terraform apply -var="ssl_certificate_arn=%SSL_CERT_ARN%" -auto-approve
    
    REM Récupération des outputs
    for /f %%i in ('terraform output -raw cognito_user_pool_id') do set USER_POOL_ID=%%i
    for /f %%i in ('terraform output -raw cognito_user_pool_client_id') do set CLIENT_ID=%%i
    for /f %%i in ('terraform output -raw api_gateway_url') do set API_URL=%%i
    for /f %%i in ('terraform output -raw cloudfront_domain_name') do set CLOUDFRONT_URL=%%i
    for /f %%i in ('terraform output -raw frontend_bucket') do set FRONTEND_BUCKET=%%i
    
    echo.
    echo ✅ Infrastructure déployée avec succès !
    echo.
    echo 📝 Configuration AWS :
    echo    - User Pool ID: !USER_POOL_ID!
    echo    - Client ID: !CLIENT_ID!
    echo    - API URL: !API_URL!
    echo    - CloudFront URL: https://!CLOUDFRONT_URL!
    echo.
    
    REM 4. Configuration frontend
    echo ⚙️  Mise à jour de la configuration frontend...
    
    cd ..
    
    (
    echo export const AWS_CONFIG = {
    echo   region: '%REGION%',
    echo   userPoolId: '!USER_POOL_ID!',
    echo   clientId: '!CLIENT_ID!',
    echo   apiUrl: '!API_URL!',
    echo };
    echo.
    echo export default AWS_CONFIG;
    ) > frontend\src\config\aws.ts

    (
    echo // Configuration des domaines autorisés
    echo export const ALLOWED_ORIGINS = [
    echo   'https://claude-serverless.daveo-dev.fr',
    echo   'https://!CLOUDFRONT_URL!',
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
    aws s3 sync dist/ s3://!FRONTEND_BUCKET! --delete --region %REGION%
    
    REM Invalidation CloudFront
    cd ..\infrastructure
    for /f %%i in ('terraform output -raw cloudfront_distribution_id') do set DISTRIBUTION_ID=%%i
    echo 🔄 Invalidation CloudFront...
    aws cloudfront create-invalidation --distribution-id !DISTRIBUTION_ID! --paths "/*" --region %REGION%
    
    echo.
    echo 🎉 Déploiement terminé avec succès !
    echo.
    echo 🌐 URLs de l'application :
    echo    - https://claude-serverless.daveo-dev.fr
    echo    - https://!CLOUDFRONT_URL!
    echo.
    echo 📚 Prochaines étapes :
    echo    1. Créer des utilisateurs dans Cognito
    echo    2. Configurer les permissions Bedrock si nécessaire
    echo    3. Tester l'application
    echo.
    
) else (
    echo ❌ Déploiement annulé
)

pause