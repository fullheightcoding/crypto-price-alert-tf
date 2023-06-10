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
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
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

resource "aws_cloudwatch_event_rule" "crypto_price_alert_cronjob_bitcoin" {
  name                = "CryptoPriceAlertCronJob-Bitcoin"
  schedule_expression = "cron(30 7 * * ? *)"  # Runs at 5:30 PM AEST (7:30 AM UTC)
  is_enabled          = true

  event_pattern = jsonencode({
    source      = ["aws.events"],
    detail_type = ["Scheduled Event"],
    detail      = {
      threshold_coin       = ["bitcoin"],
      threshold_price      = [10000],
      threshold_direction  = ["less_than"]
    }
  })
}

resource "aws_cloudwatch_event_rule" "crypto_price_alert_cronjob_ethereum" {
  name                = "CryptoPriceAlertCronJob-Ethereum"
  schedule_expression = "cron(0 1 * * ? *)"  # Runs at 1PM AEST
  is_enabled          = true

  event_pattern = jsonencode({
    source      = ["aws.events"],
    detail_type = ["Scheduled Event"],
    detail      = {
      threshold_coin       = ["ethereum"],
      threshold_price      = [1000],
      threshold_direction  = ["less_than"]
    }
  })
}

resource "aws_cloudwatch_event_rule" "crypto_price_alert_cronjob_solana" {
  name                = "CryptoPriceAlertCronJob-Solana"
  schedule_expression = "cron(0 1 * * ? *)"  # Runs at 1PM AEST
  is_enabled          = true

  event_pattern = jsonencode({
    source      = ["aws.events"],
    detail_type = ["Scheduled Event"],
    detail      = {
      threshold_coin       = ["solana"],
      threshold_price      = [10],
      threshold_direction  = ["less_than"]
    }
  })
}

resource "aws_cloudwatch_event_target" "crypto_price_alert_target_bitcoin" {
  rule      = aws_cloudwatch_event_rule.crypto_price_alert_cronjob_bitcoin.name
  arn       = aws_lambda_function.crypto_price_alert_lambda.arn
  target_id = "CryptoPriceAlertTarget-Bitcoin"
}

resource "aws_cloudwatch_event_target" "crypto_price_alert_target_ethereum" {
  rule      = aws_cloudwatch_event_rule.crypto_price_alert_cronjob_ethereum.name
  arn       = aws_lambda_function.crypto_price_alert_lambda.arn
  target_id = "CryptoPriceAlertTarget-Ethereum"
}

resource "aws_cloudwatch_event_target" "crypto_price_alert_target_solana" {
  rule      = aws_cloudwatch_event_rule.crypto_price_alert_cronjob_solana.name
  arn       = aws_lambda_function.crypto_price_alert_lambda.arn
  target_id = "CryptoPriceAlertTarget-Solana"
}

resource "aws_cloudwatch_log_group" "crypto_price_alert_logs" {
  name = "/aws/lambda/${aws_lambda_function.crypto_price_alert_lambda.function_name}"
  retention_in_days = 7
}
