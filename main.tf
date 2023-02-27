provider "aws" {
  region = "us-east-1"
}

#Create a new S3 bucket
resource "aws_s3_bucket" "report_bucket555" {
  bucket = "report-bucket555"
  acl    = "private"
}

# create a zip archive file
data "archive_file" "report_function_zip" {
  type        = "zip"
  source_dir  = "./report_function/"
  output_path = "./report_output/report_output.zip"
}

# Create a Lambda function
resource "aws_lambda_function" "report_function" {
  function_name    = "report_function"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.8"
  filename         = data.archive_file.report_function_zip.output_path                   #"./report_function.zip"
  source_code_hash = filebase64sha256(data.archive_file.report_function_zip.output_path) #"./report_function/report_function.zip")

  handler = "report_function.lambda_handler"
  timeout = 10

  environment {
    variables = {
      bucket_name = aws_s3_bucket.report_bucket555.id
    }
  }
}
# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec"

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
}
# Add the required permissions to the IAM role for the Lambda function
resource "aws_iam_policy" "lambda_s3_policy" {
  name = "lambda_s3_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.report_bucket555.id}/*"
    }
  ]
}
EOF
}
# create policy attachment for the lamba function
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
  role       = aws_iam_role.lambda_exec.name
}


#Create a CloudWatch Event Rule with a cron expression to trigger the Lambda function
resource "aws_cloudwatch_event_rule" "report_rule" {
  name                = "report_rule"
  description         = "Trigger Lambda every Sunday at 12:00 AM UTC"
  schedule_expression = "cron(0 0 ? * SUN *)"
}


#Create a Lambda Permission to allow CloudWatch to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report_function.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.report_rule.arn
}


# I'm still working on the SNS notifcation code to alert the devops team but cant finish it up at the moment due to other committments at work. Apologies.

# resource "aws_sqs_queue" "queue" {
#   name = "my-queue"
#   # other configuration options for the SQS queue
# }

# resource "aws_sns_topic" "s3_deletion_topic" {
#   name = "s3_deletion_topic"
# }

# resource "aws_sns_topic_subscription" "devops_notification" {
#   topic_arn = aws_sns_topic.s3_deletion_topic.arn
#   protocol  = "email"
#   endpoint  = "devops-team@example.com"
# }

# # resource "null_resource" "wait_for_lambda_trigger" {
# #   depends_on = [aws_lambda_permission.allow_cloudwatch]
# #   provisioner "local-exec" {
# #     command = "sleep 3m"
# #   }
# # }

# resource "aws_s3_bucket_notification" "bucket_notif" {
#   bucket     = aws_s3_bucket_acl.report_bucket555.id
#   depends_on = [aws_lambda_permission.allow_cloudwatch]

#   lambda_function {
#     lambda_function_arn = aws_lambda_function.report_function.arn
#     events              = ["s3:ObjectRemoved:*"]
#     filter_prefix       = "./report_output/" # Change this to the prefix of the S3 key you want to trigger the Lambda function on.
#   }

#   queue {
#     queue_arn = aws_sqs_queue.queue.arn
#     events    = ["s3:ObjectRemoved:*"]
#   }

#   topic {
#     topic_arn     = aws_sns_topic.s3_deletion_topic.arn
#     events        = ["s3:ObjectRemoved:*"]
#     filter_prefix = "./report_output/" # Change this to the prefix of the S3 key you want to trigger the SNS notification on.
#   }
# }
#...............................