#=== Setting up environment 
provider "aws" {
  region = "eu-west-1"
}

#=== Creating table ===
resource "aws_dynamodb_table" "ddbtable" {
  name           = "myTable-007"
  hash_key       = "UserId"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "UserId"
    type = "S"
  }
}

#=== Adding dummy record

resource "aws_dynamodb_table_item" "item1" {
  
     depends_on = [
      aws_dynamodb_table.ddbtable
    ]

table_name = aws_dynamodb_table.ddbtable.name
hash_key =  aws_dynamodb_table.ddbtable.hash_key

item = <<ITEM
{

"UserId": {"S": "UserA"},
"Name": {"S": "Tegue"},
"Surname": {"S": "Morrison"}

}
ITEM
}


#=== Creating bucket
resource "aws_s3_bucket" "b" {
  bucket = "my-baseball-buck-007"
  acl    = "private"

  tags = {
    "Name" : "Tegue Morrison"
    "Description" : "Grad-tf-assignment"
    "Department" : "Graduates"
  }
}

#=== Creating write policy
resource "aws_iam_role_policy" "write_policy" {
  name = "lambda_write_policy"
  role = aws_iam_role.writeRole.id

  policy = file("./writeRole/write_policy.json")
}

#=== Creating read policy
resource "aws_iam_role_policy" "read_policy" {
  name = "lambda_read_policy"
  role = aws_iam_role.readRole.id

  policy = file("./readRole/read_policy.json")

}

#=== Creating write role
resource "aws_iam_role" "writeRole" {
  name = "myWriteRole"

  assume_role_policy = file("./writeRole/assume_write_role_policy.json")

  tags = {
    "Name" : "Tegue Morrison"
    "Description" : "Grad-tf-assignment"
    "Department" : "Graduates"
  }

}

#=== Creating read role
resource "aws_iam_role" "readRole" {
  name = "myReadRole"

  assume_role_policy = file("./readRole/assume_read_role_policy.json")

  tags = {
    "Name" : "Tegue Morrison"
    "Description" : "Grad-tf-assignment"
    "Department" : "Graduates"
  }

}

#=== Creating write function
resource "aws_lambda_function" "writeLambda" {

  filename      = "writeterra.zip"
  function_name = "writeLambda"
  role          = aws_iam_role.writeRole.arn
  handler       = "writeterra.handler"
  runtime       = "nodejs12.x"

  tags = {
    "Name" : "Tegue Morrison"
    "Description" : "Grad-tf-assignment"
    "Department" : "Graduates"
  }
}

#=== Creating read function
resource "aws_lambda_function" "readLambda" {
  filename      = "readterra.zip"
  function_name = "readLambda"
  role          = aws_iam_role.readRole.arn
  handler       = "readterra.handler"
  runtime       = "nodejs12.x"

  tags = {
    "Name" : "Tegue Morrison"
    "Description" : "Grad-tf-assignment"
    "Department" : "Graduates"
  }
}


#=== Creating rest API
resource "aws_api_gateway_rest_api" "apiLambda" {
  name = "myAPI"

  tags = {
    "Name" : "Tegue Morrison"
    "Description" : "Grad-tf-assignment"
    "Department" : "Graduates"
  }

}

#=== creating write resource
resource "aws_api_gateway_resource" "writeResource" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  parent_id   = aws_api_gateway_rest_api.apiLambda.root_resource_id
  path_part   = "writedb"
  

}

#=== creating write method
resource "aws_api_gateway_method" "writeMethod" {
  rest_api_id   = aws_api_gateway_rest_api.apiLambda.id
  resource_id   = aws_api_gateway_resource.writeResource.id
  http_method   = "POST"
  authorization = "NONE"
  
}

#=== creating read resource
resource "aws_api_gateway_resource" "readResource" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  parent_id   = aws_api_gateway_rest_api.apiLambda.root_resource_id
  path_part   = "readdb"

}

#=== creating read method
resource "aws_api_gateway_method" "readMethod" {
  rest_api_id   = aws_api_gateway_rest_api.apiLambda.id
  resource_id   = aws_api_gateway_resource.readResource.id
  http_method   = "GET"
  authorization = "NONE"
}



#=== creating API write integration
resource "aws_api_gateway_integration" "writeInt" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  resource_id = aws_api_gateway_resource.writeResource.id
  http_method = aws_api_gateway_method.writeMethod.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.writeLambda.invoke_arn

}

#=== creating API read integration
resource "aws_api_gateway_integration" "readInt" {
  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  resource_id = aws_api_gateway_resource.readResource.id
  http_method = aws_api_gateway_method.readMethod.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.readLambda.invoke_arn

}


#=== creating API deployment 
resource "aws_api_gateway_deployment" "apideploy" {
  depends_on = [aws_api_gateway_integration.writeInt, aws_api_gateway_integration.readInt]

  rest_api_id = aws_api_gateway_rest_api.apiLambda.id
  stage_name  = "Prod"
  
}

#=== creating lambda write permission
resource "aws_lambda_permission" "writePermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.writeLambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/*/*/*"

}

#=== creating lambda read permission
resource "aws_lambda_permission" "readPermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.readLambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.apiLambda.execution_arn}/*/*/*"

}

#=== Output
output "base_url" {
  value = aws_api_gateway_deployment.apideploy.invoke_url
}