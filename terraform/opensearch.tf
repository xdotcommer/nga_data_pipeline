data "terraform_remote_state" "opensearch" {
  backend = "local"

  config = {
    path = "terraform.tfstate"
  }
}

# OpenSearch Serverless Collection
resource "aws_opensearchserverless_collection" "main" {
  count = var.environment == "local" ? 0 : 1

  name        = "${var.project_name}-${var.environment}"
  description = "Collection for NGA artwork data"
  type        = "SEARCH"

  # Wait for the security policies to be created first
  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]

  tags = var.tags
}

locals {
  opensearch_endpoint = var.environment == "local" ? "https://localhost:9200" : (
    length(aws_opensearchserverless_collection.main) > 0 ? aws_opensearchserverless_collection.main[0].collection_endpoint : null
  )
}

# Encryption Policy
resource "aws_opensearchserverless_security_policy" "encryption" {
  count = var.environment == "local" ? 0 : 1

  name        = "nga-encrypt-${var.environment}"
  type        = "encryption"
  description = "Encryption policy for NGA collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection",
        Resource     = ["collection/${var.project_name}-${var.environment}"]
      }
    ],
    AWSOwnedKey = true
  })
}


# Network Policy
resource "aws_opensearchserverless_security_policy" "network" {
  count = var.environment == "local" ? 0 : 1

  name        = "nga-network-${var.environment}"
  type        = "network"
  description = "Network security policy for NGA collection"

  policy = jsonencode([
    {
      Description = "Public access for NGA collection",
      Rules = [
        {
          ResourceType = "collection",
          Resource = [
            "collection/${var.project_name}-${var.environment}"
          ]
        }
      ],
      AllowFromPublic = true
    }
  ])

  depends_on = [aws_opensearchserverless_security_policy.encryption]
}

# Data Access Policy
# Data Access Policy
resource "aws_opensearchserverless_access_policy" "main" {
  count       = var.environment == "local" ? 0 : 1
  name        = "unified-access-policy-${var.environment}"
  type        = "data"
  description = "Unified access policy for OpenSearch Serverless"

  policy = jsonencode([
    {
      Principal = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-lambda-role-${var.environment}"
      ],
      Rules = [
        {
          ResourceType = "collection",
          Resource     = ["collection/${var.project_name}-${var.environment}"],
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index",
          Resource     = ["index/${var.project_name}-${var.environment}/*"],
          Permission   = ["aoss:*"]
        }
      ]
    }
  ])
}

# Update the Lambda IAM policy
resource "aws_iam_role_policy" "lambda_opensearch_serverless" {
  name = "opensearch-serverless-access-${var.environment}"
  role = aws_iam_role.lambda_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Allow BatchGetCollection and DescribeCollection for the specific collection
      {
        Effect = "Allow",
        Action = [
          "aoss:BatchGetCollection",
          "aoss:GetCollection",
          "aoss:ListCollections",
          "aoss:CreateCollection",
          "aoss:UpdateCollection",
          "aoss:DeleteCollection",
          "aoss:CreateSecurityPolicy",
          "aoss:GetSecurityPolicy",
          "aoss:ListSecurityPolicies",
          "aoss:*" # Broad permission as a fallback
        ],
        "Resource" : "*"
      },
      # Allow ListCollections at the account level
      {
        Effect   = "Allow",
        Action   = "aoss:ListCollections",
        Resource = "*"
      },
      # Allow index-level actions
      {
        Effect = "Allow",
        "Action" : [
          "aoss:CreateIndex",
          "aoss:DeleteIndex",
          "aoss:UpdateIndex",
          "aoss:GetIndex",
          "aoss:ListIndexes",
          "aoss:WriteDocuments",
          "aoss:ReadDocuments",
          "aoss:BatchGetCollection",
          "aoss:GetCollection",
          "aoss:ListCollections"
        ],
        "Resource" : "*"
      },
      # Allow dashboard actions
      {
        Effect = "Allow",
        Action = [
          "aoss:CreateDashboard",
          "aoss:DeleteDashboard",
          "aoss:DescribeDashboard",
          "aoss:ListDashboard",
          "aoss:UpdateDashboard"
        ],
        Resource = ["arn:aws:aoss:${var.aws_region}:${local.account_id}:dashboards/*"]
      }
    ]
  })
}


