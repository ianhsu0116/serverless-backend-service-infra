locals {
  # Define all HTTP routes here. Each entry maps to an existing Lambda function.
  routes = {
    hello = {
      path        = "hello"
      method      = "GET"
      lambda_name = "helloworld"
      auth_type   = "NONE"
    }
    admin_hello = {
      path        = "admin/hello"
      method      = "GET"
      lambda_name = "helloworld-private"
      auth_type   = "JWT"
    }
  }

  route_configs = {
    for key, route in local.routes : key => merge(
      route,
      {
        route_key       = "${route.method} /${route.path}"
        integration_uri = var.lambda_functions[route.lambda_name].invoke_arn
        source_arn      = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*${route.path}"
      }
    )
  }
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-${var.environment}-http-api"
  protocol_type = "HTTP"

  tags = merge(var.common_tags, {
    Component = "api-gateway"
  })
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  name             = "${var.project_name}-${var.environment}-jwt-authorizer"
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.cognito.admin_app_client_id]
    issuer   = var.cognito.issuer_url
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  tags = merge(var.common_tags, {
    Component = "api-gateway"
  })
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each = local.route_configs

  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.integration_uri
  integration_method     = "POST"
  payload_format_version = "2.0"

  timeout_milliseconds = 29000
}

resource "aws_apigatewayv2_route" "this" {
  for_each = local.route_configs

  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = each.value.route_key
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"

  authorization_type = each.value.auth_type
  authorizer_id      = each.value.auth_type == "JWT" ? aws_apigatewayv2_authorizer.jwt.id : null
}

resource "aws_lambda_permission" "api_invoke" {
  for_each = local.route_configs

  statement_id  = "AllowHttpApiInvoke-${each.key}-${var.environment}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_functions[each.value.lambda_name].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = each.value.source_arn
}
