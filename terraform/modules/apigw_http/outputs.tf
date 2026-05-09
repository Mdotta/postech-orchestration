output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "invoke_url" {
  value = "${aws_apigatewayv2_api.this.api_endpoint}/${aws_apigatewayv2_stage.this.name}"
}

