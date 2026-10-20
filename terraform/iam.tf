data "aws_iam_policy_document" "lambda_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_permissions_policy" {
  statement {
    sid       = "DynamoDBAccess"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.submissions.arn]
  }
  statement {
    sid       = "CloudWatchLogsAccess"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda_logs.arn}:*"]
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.project_name}-lambda-execution-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust_policy.json
}

resource "aws_iam_policy" "lambda_permissions_policy" {
  name   = "${var.project_name}-lambda-permissions-policy"
  policy = data.aws_iam_policy_document.lambda_permissions_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_permissions_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_permissions_policy.arn
}