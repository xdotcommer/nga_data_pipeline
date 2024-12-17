resource "aws_opensearchserverless_access_policy" "data_access_policy" {
  name = "data-access-search-demo"
  type = "data"

  policy = jsonencode(
    [
      {
        Principal = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${data.aws_caller_identity.current.user_id}"
        ]
        Rules = [
          # Permissions for collections
          {
            ResourceType = "collection"
            Resource = [
              "collection/nga-data-pipeline-demo"
            ]
            Permission = [
              "aoss:DescribeCollectionItems",
              "aoss:UpdateCollectionItems"
            ]
          },
          # Permissions for indices
          {
            ResourceType = "index"
            Resource = [
              "index/nga-data-pipeline-demo/*"
            ]
            Permission = [
              "aoss:ReadDocument",
              "aoss:DescribeIndex"
            ]
          }
        ]
      }
    ]
  )
}
