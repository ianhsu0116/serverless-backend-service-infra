locals {
  # Defaults shared by all Lambda functions unless overridden.
  lambda_defaults = {
    memory_size   = 128
    timeout       = 3
    architectures = ["x86_64"]
    env_vars = {
      STAGE = var.environment
    }
  }

  # Per-function overrides. Add new entries here to provision additional Lambdas.
  lambda_overrides = {
    helloworld = {
      timeout = 5
      env_vars = {
        TEST_SECRET = "Test Secret Value"
      }
    }
    helloworld-private = {
      timeout = 5
      env_vars = {
        TEST_SECRET = "Test Secret Value - private"
      }
    }
  }

  lambda_configs = {
    for name, override in local.lambda_overrides : name => merge(
      local.lambda_defaults,
      override,
      {
        env_vars = merge(
          local.lambda_defaults.env_vars,
          lookup(override, "env_vars", {})
        ),
        function_name = "${name}-${var.environment}",
        image_uri     = "${var.ecr_repo_prefix}/lambda/${name}:${var.image_tag}"
      }
    )
  }

  lambda_managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
  ]
}

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-${var.environment}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Component = "lambda"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_managed" {
  for_each   = toset(local.lambda_managed_policies)
  role       = aws_iam_role.lambda_execution.name
  policy_arn = each.value
}

resource "aws_lambda_function" "this" {
  for_each = local.lambda_configs

  function_name = each.value.function_name
  package_type  = "Image"
  role          = aws_iam_role.lambda_execution.arn
  image_uri     = each.value.image_uri
  architectures = each.value.architectures
  memory_size   = each.value.memory_size
  timeout       = each.value.timeout
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      {
        ENV = var.environment
      },
      lookup(each.value, "env_vars", {})
    )
  }

  tags = merge(var.common_tags, {
    Component = "lambda"
  })
}
