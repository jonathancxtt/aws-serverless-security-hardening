data "archive_file" "lambda" {
    type = "zip"
    source_file = "${path.module}/../lambda/handler.py"
    output_path = "${path.module}/../lambda/handler.zip"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-form-handler"
  retention_in_days = 14
}

resource "aws_lambda_function" "form_handler" {
  function_name = "${var.project_name}-form-handler"
  role = aws_iam_role.lambda_execution_role.arn
  handler = "handler.lambda_handler"
  runtime = "python3.12"

  filename = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  environment {
    variables = {
        DYNAMODB_TABLE_NAME = aws_dynamodb_table.submissions.name
    }
  }
}