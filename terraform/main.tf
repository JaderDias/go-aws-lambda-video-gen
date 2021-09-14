provider "aws" {
  region = var.aws_region
}

resource "random_pet" "this" {
  length = 2
}

data "aws_caller_identity" "current" {}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  environment     = "dev"
  lambda_handler  = "hello"
  name            = "go-lambda-terraform-setup"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../bin/hello"
  output_path = "../bin/hello.zip"
}

/*
* IAM
*/

// Role
data "aws_iam_policy_document" "assume_role" {
  policy_id = "${local.name}-lambda"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name                = "${local.name}-lambda"
  assume_role_policy  = data.aws_iam_policy_document.assume_role.json
}

// Logs Policy
data "aws_iam_policy_document" "logs" {
  policy_id = "${local.name}-lambda-logs"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]

    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.name}*:*"
    ]
  }
}

resource "aws_iam_policy" "logs" {
  name   = "${local.name}-lambda-logs"
  policy = data.aws_iam_policy_document.logs.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  depends_on  = [aws_iam_role.lambda, aws_iam_policy.logs]
  role        = aws_iam_role.lambda.name
  policy_arn  = aws_iam_policy.logs.arn
}

// DynamoDb Policy
data "aws_iam_policy_document" "dynamodb" {
  policy_id = "${local.name}-lambda-dynamodb"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["dynamodb:PutItem"]

    resources = [
      module.dynamodb_table.dynamodb_table_arn
    ]
  }
}

resource "aws_iam_policy" "dynamodb" {
  name   = "${local.name}-lambda-dynamodb"
  policy = data.aws_iam_policy_document.dynamodb.json
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  depends_on  = [aws_iam_role.lambda, aws_iam_policy.dynamodb]
  role        = aws_iam_role.lambda.name
  policy_arn  = aws_iam_policy.dynamodb.arn
}

/*
* Cloudwatch
*/

// Log group
resource "aws_cloudwatch_log_group" "log" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 7
}

/*
* Lambda
*/

// Function
resource "aws_lambda_function" "func" {
  filename          = data.archive_file.lambda_zip.output_path
  function_name     = local.name
  role              = aws_iam_role.lambda.arn
  handler           = local.lambda_handler
  source_code_hash  = filebase64sha256(data.archive_file.lambda_zip.output_path)
  runtime           = "go1.x"
  memory_size       = 1024
  timeout           = 30

  environment {
    variables = {
      DYNAMODB_TABLE_ID = module.dynamodb_table.dynamodb_table_id
    }
  }
}

resource "aws_cloudwatch_event_rule" "every_one_minute" {
  name                = "every-one-minute"
  description         = "Fires every one minutes"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "check_foo_every_one_minute" {
  rule      = "${aws_cloudwatch_event_rule.every_one_minute.name}"
  target_id = "lambda"
  arn       = "${aws_lambda_function.func.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.func.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.every_one_minute.arn}"
}

module "dynamodb_table" {
  source   = "terraform-aws-modules/dynamodb-table/aws"

  name      = "my-table-${random_pet.this.id}"
  hash_key  = "Id"
  range_key = "Title"

  attributes = [
    {
      name = "Id"
      type = "N"
    },
    {
      name = "Title"
      type = "S"
    },
    {
      name = "Age"
      type = "N"
    }
  ]

  global_secondary_indexes = [
    {
      name               = "TitleIndex"
      hash_key           = "Title"
      range_key          = "Age"
      projection_type    = "INCLUDE"
      non_key_attributes = ["Id"]
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "staging"
  }
}