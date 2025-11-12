@echo off
echo 🔐 ÉTAPE 1 : Création du certificat SSL pour CloudFront
echo ==================================================

cd /d "%~dp0"

REM Variables
set PROJECT_NAME=claude-serverless
set ENVIRONMENT=prod
set DOMAIN=claude-serverless.daveo-dev.fr

echo 🏗️  Configuration :
echo    - Projet : %PROJECT_NAME%
echo    - Environnement : %ENVIRONMENT%
echo    - Domaine : %DOMAIN%
echo.

REM Vérifications
where terraform >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ Terraform n'est pas installé
    pause
    exit /b 1
)

REM Initialisation Terraform
echo 📦 Initialisation Terraform...
terraform init

REM Configuration temporaire pour l'étape 1
echo 🚀 Création du certificat SSL...
(
echo terraform {
echo   required_version = "^>= 1.0"
echo   required_providers {
echo     aws = {
echo       source  = "hashicorp/aws"
echo       version = "~^> 5.0"
echo     }
echo   }
echo }
echo.
echo provider "aws" {
echo   region = "eu-west-3"
echo }
echo.
echo provider "aws" {
echo   alias  = "us_east_1"
echo   region = "us-east-1"
echo }
echo.
echo module "ssl_certificate" {
echo   source = "./modules/ssl-certificate"
echo   
echo   domain_name = "%DOMAIN%"
echo   
echo   providers = {
echo     aws.us_east_1 = aws.us_east_1
echo   }
echo   
echo   tags = {
echo     Project     = "%PROJECT_NAME%"
echo     Environment = "%ENVIRONMENT%"
echo     ManagedBy   = "Terraform"
echo   }
echo }
echo.
echo output "certificate_arn" {
echo   description = "ARN du certificat SSL (à conserver pour l'étape 2)"
echo   value       = module.ssl_certificate.certificate_arn
echo }
echo.
echo output "dns_validation_record" {
echo   description = "Enregistrement DNS à créer pour valider le certificat"
echo   value = {
echo     name   = module.ssl_certificate.validation_record_name
echo     value  = module.ssl_certificate.validation_record_value
echo     type   = module.ssl_certificate.validation_record_type
echo     ttl    = "300"
echo   }
echo }
) > step1-terraform.tf

REM Apply avec le fichier temporaire
terraform apply -auto-approve

REM Récupération des outputs
for /f %%i in ('terraform output -raw certificate_arn') do set CERT_ARN=%%i
for /f %%i in ('terraform output -json dns_validation_record ^| jq -r ".name"') do set DNS_NAME=%%i
for /f %%i in ('terraform output -json dns_validation_record ^| jq -r ".value"') do set DNS_VALUE=%%i
for /f %%i in ('terraform output -json dns_validation_record ^| jq -r ".type"') do set DNS_TYPE=%%i

REM Instructions
echo.
echo ✅ Certificat SSL créé avec succès !
echo.
echo 🎯 PROCHAINE ÉTAPE : VALIDATION DNS
echo ==================================
echo.
echo Créer l'enregistrement DNS suivant dans votre zone daveo-dev.fr :
echo.
echo    Type  : %DNS_TYPE%
echo    Nom   : %DNS_NAME%
echo    Valeur: %DNS_VALUE%
echo    TTL   : 300
echo.
echo 📋 ARN du certificat (à conserver) :
echo    %CERT_ARN%
echo.

REM Sauvegarde de l'ARN
echo %CERT_ARN% > .ssl-certificate-arn
echo 💾 ARN sauvegardé dans .ssl-certificate-arn

REM Nettoyage
del step1-terraform.tf

echo.
echo ⏳ Une fois l'enregistrement DNS créé :
echo    1. Attendre la validation (5-30 minutes)
echo    2. Exécuter : step2-deploy-infrastructure.bat "%CERT_ARN%"
echo.
echo 🔚 Étape 1 terminée. Configurez le DNS et passez à l'étape 2.

pause