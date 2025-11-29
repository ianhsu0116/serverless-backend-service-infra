output "api_endpoints" {
  description = "HTTP API invoke URLs and routes."
  value = {
    http_api = {
      api_id     = aws_apigatewayv2_api.http_api.id
      invoke_url = aws_apigatewayv2_stage.default.invoke_url
      routes = {
        for key, route in local.route_configs : key => {
          method = route.method
          path   = route.path
          url    = "${aws_apigatewayv2_stage.default.invoke_url}${route.path}"
        }
      }
    }
  }
}
