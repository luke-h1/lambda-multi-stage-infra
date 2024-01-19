resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = var.project_name
  description = "API Gateway for ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.hello.arn}:$${stageVariables.stage}/invocations"
}

resource "aws_api_gateway_deployment" "deployment_staging" {
  depends_on = [
    aws_api_gateway_integration.lambda
  ]
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
}

resource "aws_api_gateway_stage" "staging" {
  deployment_id = aws_api_gateway_deployment.deployment_dev.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "staging"

  variables = {
    "stage" = "staging"
  }
}

resource "aws_api_gateway_deployment" "deployment_live" {
  depends_on = [
    aws_api_gateway_integration.lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
}


resource "aws_api_gateway_stage" "live" {
  deployment_id = aws_api_gateway_deployment.deployment_live.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "live"

  variables = {
    "stage" = "live"
  }
}

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.api_gateway.id
}

output "hello_staging" {
  value = "${aws_api_gateway_stage.staging.invoke_url}/hello"
}

output "hello_live" {
  value = "${aws_api_gateway_stage.live.invoke_url}/hello"
}
