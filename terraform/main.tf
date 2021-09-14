provider "aws" {
  region = var.aws_region
}

resource "random_pet" "this" {
  length = 2
}

module "dynamodb_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  name      = "my-table-${random_pet.this.id}"
  hash_key  = "Id"
  range_key = "Title"

  attributes = [
    {
      name = "Id"
      type = "N"
    },
    {
      name = "Title"
      type = "S"
    },
    {
      name = "Age"
      type = "N"
    }
  ]

  global_secondary_indexes = [
    {
      name               = "TitleIndex"
      hash_key           = "Title"
      range_key          = "Age"
      projection_type    = "INCLUDE"
      non_key_attributes = ["Id"]
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "staging"
  }
}

module "my_function" {
  source         = "./modules/function"

  function_name  = "my-function"
  lambda_handler = "hello"
  source_file = "../bin/hello"
  schedule_expression = "rate(1 day)"
  dynamodb_table_id = module.dynamodb_table.dynamodb_table_id
  dynamodb_table_arn = module.dynamodb_table.dynamodb_table_arn
}