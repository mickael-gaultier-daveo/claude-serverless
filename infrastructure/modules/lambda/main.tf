# Rôle IAM pour les fonctions Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Politique IAM pour les logs CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Politique IAM pour Bedrock
resource "aws_iam_role_policy" "bedrock_policy" {
  name = "${var.project_name}-${var.environment}-lambda-bedrock-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:eu-west-3:344060441891:inference-profile/eu.anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:eu-north-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:eu-west-3::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:eu-south-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:eu-south-2::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:eu-west-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
        ]
      }
    ]
  })
}

# Politique IAM pour DynamoDB
resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "${var.project_name}-${var.environment}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project_name}-${var.environment}-*"
      }
    ]
  })
}

# Lambda Layer pour les dépendances communes Python
resource "aws_lambda_layer_version" "dependencies" {
  filename         = "../backend-python/layers/dependencies.zip"
  layer_name       = "${var.project_name}-${var.environment}-python-dependencies"
  source_code_hash = filebase64sha256("../backend-python/layers/dependencies.zip")

  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# Fonction Lambda pour le chat
resource "aws_lambda_function" "chat_handler" {
  filename         = "../backend-python/dist/chat-handler.zip"
  function_name    = "${var.project_name}-${var.environment}-chat-handler"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("../backend-python/dist/chat-handler.zip")
  runtime         = "python3.9"
  timeout         = 30

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      ENVIRONMENT = var.environment
      COGNITO_USER_POOL_ID = var.cognito_user_pool_id
      DYNAMODB_TABLE = "${var.project_name}-${var.environment}-chat-history"
    }
  }

  tags = var.tags
}

# Fonction Lambda pour le traitement de fichiers
resource "aws_lambda_function" "file_processor" {
  filename         = "../backend-python/dist/file-processor.zip"
  function_name    = "${var.project_name}-${var.environment}-file-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("../backend-python/dist/file-processor.zip")
  runtime         = "python3.9"
  timeout         = 60

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      ENVIRONMENT = var.environment
      COGNITO_USER_POOL_ID = var.cognito_user_pool_id
      DYNAMODB_TABLE = "${var.project_name}-${var.environment}-chat-history"
    }
  }

  tags = var.tags
}

# Permissions pour API Gateway d'invoquer les fonctions Lambda
resource "aws_lambda_permission" "chat_handler_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

resource "aws_lambda_permission" "file_processor_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}