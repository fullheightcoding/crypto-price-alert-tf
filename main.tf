resource "aws_lambda_function" "crypto_price_alert_lambda" {
  function_name         = "CryptoPriceAlert"
  runtime               = "python3.10"
  handler               = "crypto_price_alert_lambda.lambda_handler"
  filename              = "..\\..\\python-project\\crypto-price-alert-lambda\\crypto_price_alert_lambda.zip"
  source_code_hash      = filebase64sha256("..\\..\\python-project\\crypto-price-alert-lambda\\crypto_price_alert_lambda.zip")
  role                  = aws_iam_role.lambda_execution_role.arn
  publish               = true
  timeout               = 10
  memory_size           = 128

  tracing_config {
    mode = "Active"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "CryptoPriceAlertLambdaRole"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name        = "CryptoPriceAlertLambdaPolicy"
  description = "Policy for the CryptoPriceAlert Lambda function"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.crypto_price_alert_topic.arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = aws_ssm_parameter.crypto_price_alert_sns_topic_arn.arn
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.crypto_price_alert_lambda.arn
      }      
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

#lambda dynamodb policy
resource "aws_iam_policy" "lambda_execution_policy_dyanamodb" {
  name        = "CryptoPriceAlertLambdaDynamoDBPolicy"
  description = "Policy for the CryptoPriceAlert Lambda function"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.crypto_prices.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_dynamodb_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_execution_policy_dyanamodb.arn
  role       = aws_iam_role.lambda_execution_role.name
}

resource "aws_ssm_parameter" "crypto_price_alert_sns_topic_arn" {
  name  = "/crypto_price_alert/sns_topic_arn"
  value = aws_sns_topic.crypto_price_alert_topic.arn
  type  = "String"

  tags = {
    Name = "Crypto Price Alert SNS Topic ARN"
  }
}

resource "aws_sns_topic" "crypto_price_alert_topic" {
  name = "CryptoPriceAlertTopic"
}

resource "aws_sns_topic_subscription" "crypto_price_alert_subscription" {
  topic_arn = aws_sns_topic.crypto_price_alert_topic.arn
  protocol  = "email"
  endpoint  = "mark.dodgson.developer@gmail.com"
}

resource "aws_lambda_permission" "sns_publish_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crypto_price_alert_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.crypto_price_alert_topic.arn
}

resource "aws_cloudwatch_log_group" "crypto_price_alert_logs" {
  name = "/aws/lambda/${aws_lambda_function.crypto_price_alert_lambda.function_name}"
  retention_in_days = 7
}

#new section to correctly add bitcoin, ethereum, and solana scheduled event that runs every hours at UTC 2:00AM
resource "aws_cloudwatch_event_rule" "eventbridge_schedule_bitcoin" {
  name                = "CryptoPriceAlert-ScheduleCronJob24Hours-Bitcoin"
  description         = "EventBridge schedule to trigger Lambda function"
  schedule_expression = "cron(0 2 * * ? *)"  # Starts today at 2:00 AM UTC and runs every 24 hours
}

resource "aws_cloudwatch_event_target" "lambda_target_bitcoin" {
  rule = aws_cloudwatch_event_rule.eventbridge_schedule_bitcoin.name
  arn  = aws_lambda_function.crypto_price_alert_lambda.arn
  input = jsonencode({
    threshold_coin      = "bitcoin"
    threshold_price     = 20000
    threshold_direction = "less_than"
  })
}

resource "aws_cloudwatch_event_rule" "eventbridge_schedule_ethereum" {
  name                = "CryptoPriceAlert-ScheduleCronJob24Hours-Ethereum"
  description         = "EventBridge schedule to trigger Lambda function"
  schedule_expression = "cron(0 2 * * ? *)"  # Starts today at 2:00 AM UTC and runs every 24 hours
}

resource "aws_cloudwatch_event_target" "lambda_target_ethereum" {
  rule = aws_cloudwatch_event_rule.eventbridge_schedule_ethereum.name
  arn  = aws_lambda_function.crypto_price_alert_lambda.arn
  input = jsonencode({
    threshold_coin      = "ethereum"
    threshold_price     = 1000
    threshold_direction = "less_than"
  })
}

resource "aws_cloudwatch_event_rule" "eventbridge_schedule_solana" {
  name                = "CryptoPriceAlert-ScheduleCronJob24Hours-Solana"
  description         = "EventBridge schedule to trigger Lambda function"
  schedule_expression = "cron(0 2 * * ? *)"  # Starts today at 2:00 AM UTC and runs every 24 hours
}

resource "aws_cloudwatch_event_target" "lambda_target_solana" {
  rule = aws_cloudwatch_event_rule.eventbridge_schedule_solana.name
  arn  = aws_lambda_function.crypto_price_alert_lambda.arn
  input = jsonencode({
    threshold_coin      = "solana"
    threshold_price     = 10
    threshold_direction = "less_than"
  })
}

resource "aws_dynamodb_table" "crypto_prices" {
  name           = "CryptoPrices"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "CryptoSymbol"

  attribute {
    name = "CryptoSymbol"
    type = "S"
  }
}