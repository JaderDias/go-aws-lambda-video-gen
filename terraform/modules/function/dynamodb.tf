data "aws_iam_policy_document" "dynamodb" {
  policy_id = "${var.function_name}-lambda-dynamodb"
  version   = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["dynamodb:PutItem"]

    resources = [
      var.dynamodb_table_arn
    ]
  }
}

resource "aws_iam_policy" "dynamodb" {
  name   = "${var.function_name}-lambda-dynamodb"
  policy = data.aws_iam_policy_document.dynamodb.json
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  depends_on = [aws_iam_role.lambda, aws_iam_policy.dynamodb]
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.dynamodb.arn
}
