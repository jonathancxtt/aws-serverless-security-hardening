resource "aws_api_gateway_rest_api" "form_api" {
  name = "${var.project_name}-api"
}

resource "aws_api_gateway_resource" "form_endpoint" {
  parent_id = aws_api_gateway_rest_api.form_api.root_resource_id
  path_part = "submit"
  rest_api_id = aws_api_gateway_rest_api.form_api.id
}

resource "aws_api_gateway_method" "form_method" {
  rest_api_id   = aws_api_gateway_rest_api.form_api.id
  resource_id   = aws_api_gateway_resource.form_endpoint.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "form_integration" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id
  resource_id = aws_api_gateway_resource.form_endpoint.id
  http_method = "POST"
  type = "AWS_PROXY"

  integration_http_method = "POST"
  uri = aws_lambda_function.form_handler.invoke_arn
}

//Options Configuration to handle CORS integration
resource "aws_api_gateway_method" "options_method" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id
  resource_id = aws_api_gateway_resource.form_endpoint.id
  http_method = "OPTIONS"
  authorization = "NONE"
}