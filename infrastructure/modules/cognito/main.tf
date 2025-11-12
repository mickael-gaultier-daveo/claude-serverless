resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}-user-pool"

  # Configuration des mots de passe
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Configuration des attributs utilisateur
  username_attributes = ["email"]
  
  # Configuration de l'email
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Configuration de la vérification
  auto_verified_attributes = ["email"]

  # Messages de vérification
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_CODE"
    email_subject         = "Votre code de vérification"
    email_message         = "Votre code de vérification est {####}"
  }

  # Schéma des attributs
  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable            = true
  }

  schema {
    attribute_data_type = "String"
    name               = "name"
    required           = false
    mutable            = true
  }

  # Ignorer les changements de schéma pour éviter les conflits
  lifecycle {
    ignore_changes = [schema]
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Configuration OAuth
  generate_secret                      = false
  explicit_auth_flows                  = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH", 
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
  supported_identity_providers         = ["COGNITO"]
  
  # URLs de callback (sera mis à jour avec le domaine CloudFront)
  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Configuration des tokens
  access_token_validity  = 60    # minutes
  id_token_validity     = 60    # minutes
  refresh_token_validity = 30   # jours

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Prévenir la suppression accidentelle
  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_identity_pool" "main" {
  identity_pool_name      = "${var.project_name}-${var.environment}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.main.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = false
  }

  tags = var.tags
}

# Rôles IAM pour Identity Pool
resource "aws_iam_role" "authenticated" {
  name = "${var.project_name}-${var.environment}-cognito-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "authenticated" {
  name = "${var.project_name}-${var.environment}-cognito-authenticated-policy"
  role = aws_iam_role.authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-sync:*",
          "cognito-identity:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    "authenticated" = aws_iam_role.authenticated.arn
  }
}