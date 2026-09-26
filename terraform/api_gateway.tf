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
resource "aws_api_gateway_method" "cors_options_method" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id
  resource_id = aws_api_gateway_resource.form_endpoint.id
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id
  resource_id = aws_api_gateway_resource.form_endpoint.id
  http_method = aws_api_gateway_method.cors_options_method.http_method
  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id
  resource_id = aws_api_gateway_resource.form_endpoint.id
  http_method = aws_api_gateway_method.cors_options_method.http_method
  status_code = "200"

  depends_on = [aws_api_gateway_integration.cors_integration]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_method_response" "cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id
  resource_id = aws_api_gateway_resource.form_endpoint.id
  http_method = aws_api_gateway_method.cors_options_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_deployment" "form_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id

  depends_on = [ 
    aws_api_gateway_integration.form_integration,
    aws_api_gateway_integration.cors_integration
   ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api_policy.ip_restrict.policy
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id
  deployment_id = aws_api_gateway_deployment.form_api_deployment.id
  stage_name = "prod"
}

resource "aws_lambda_permission" "aws_gateway_invoke" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.form_handler.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.form_api.execution_arn}/*/*"
}

resource "aws_api_gateway_rest_api_policy" "ip_restrict" {
  rest_api_id = aws_api_gateway_rest_api.form_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "execute-api:Invoke"
      Resource  = "${aws_api_gateway_rest_api.form_api.execution_arn}/*"
      Condition = {
        IpAddress = {
          "aws:SourceIp" = ["${var.my_ip}"]
        }
      }
    }]
  })
}