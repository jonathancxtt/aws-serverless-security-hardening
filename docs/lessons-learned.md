# Troubleshooting / Lessons Learned

Real problems hit while building this project, each written up as Problem, Investigation, Root Cause, Resolution, and Lesson.

[Back to README](../README.md)

---

## Serverless Runtime Has No Access to Local Files

**Problem**

When configuring Lambda to write to DynamoDB, I assumed the table name could be passed the same way local Python applications read from a `.env` file, or referenced directly from `terraform.tfvars` or the Terraform state file.

**Investigation**

I asked whether `terraform.tfvars` could serve as a runtime configuration source for Lambda, then whether the state file could be referenced instead. Both questions came from thinking about this as a local application problem where the program and its config share the same file system.

**Root Cause**

Lambda does not run on your local machine. It runs on a managed server in AWS that has no access to your local file system, your `terraform.tfvars`, or your state file. Those files exist only on your machine during `terraform plan` and `terraform apply`. Once the function is deployed, they play no role in what Lambda can access at runtime.

**Resolution**

Environment variables are injected into the Lambda runtime at deploy time via the `environment` block in `lambda.tf`. Terraform reads the value from `terraform.tfvars` during apply, passes it to AWS, and AWS stores it against the function. Lambda reads it at execution time using `os.environ['DYNAMODB_TABLE_NAME']`. The local file never touches the Lambda container.

**Lesson**

Serverless changes the contract between configuration and code. In traditional application development the program and its config share a file system. In serverless there is no shared file system. Any value Lambda needs at runtime must be provided through AWS-managed mechanisms: environment variables for non-sensitive config, Secrets Manager or Parameter Store for secrets. Configuration does not live next to the code. It lives in the infrastructure layer and is handed to the code at invocation.

## Lambda Permission and IAM Are Two Separate Permission Systems

**Problem**

API Gateway returned a 403 when attempting to invoke Lambda despite Lambda having a correctly configured IAM execution role.

**Investigation**

The IAM role was confirmed to exist with the correct trust policy and permissions. The issue was not with what Lambda could do but with whether Lambda could be called at all.

**Root Cause**

There are two distinct permission systems at play. IAM grants Lambda permission to call other AWS services: DynamoDB, CloudWatch, and so on. `aws_lambda_permission` grants external AWS services permission to invoke Lambda itself. These are not the same thing and neither covers the other. Lambda's IAM role says nothing about who can trigger the function.

**Resolution**

Added `aws_lambda_permission` to `api_gateway.tf` with `principal = "apigateway.amazonaws.com"` and `source_arn` scoped to the API's execution ARN. This explicitly grants API Gateway the right to invoke the function.

**Lesson**

IAM controls what Lambda can do. `aws_lambda_permission` controls who can call Lambda. Both must exist. A Lambda function with a perfect IAM role but no resource-based permission will reject every invocation from API Gateway with a 403. Always check both permission layers when debugging invocation failures.

## Terraform Does Not Roll Back on Failure

**Problem**

`terraform apply` failed partway through with an error on `aws_api_gateway_integration_response`. Resources created before the failure remained in AWS with no way to automatically undo them.

**Investigation**

After the error, the AWS console showed that some resources existed and some did not. It was unclear whether re-running apply would duplicate the resources that had already been created or cause further errors.

**Root Cause**

Terraform is not transactional. When an apply fails, it does not roll back the resources that already succeeded. The state file is updated to reflect what was created before the failure. Everything after the point of failure is simply not created.

**Resolution**

Fixed the error, added `depends_on = [aws_api_gateway_integration.cors_integration]` to the integration response to ensure the parent integration existed before the response was created, then ran `terraform apply` again. Terraform read the state file, identified what already existed, skipped those resources, and only created what was missing.

**Lesson**

A failed `terraform apply` is always safe to retry after fixing the underlying error. Terraform will never duplicate resources that already exist in state. The state file is the source of truth. This is why protecting the state file matters. If it is lost or corrupted, Terraform loses track of what exists and risks creating duplicates or failing to manage existing resources.

## API Gateway Resource Policy Changes Require a Redeployment

**Problem**

After applying an IP restriction via `aws_api_gateway_rest_api_policy`, requests from external IPs were still returning 200 and writing records to DynamoDB. The policy was visible in the API Gateway console but was not enforcing anything.

**Investigation**

The resource policy was confirmed present and correctly formatted in the AWS console. A notice at the top of the Resource Policy page read: "You must redeploy your API for changes to this policy to take effect."

**Root Cause**

API Gateway stages point at a specific deployment snapshot. When a resource policy is added or changed, the existing deployment snapshot does not automatically update. The stage continues serving requests using the old snapshot which has no knowledge of the new policy.

**Resolution**

Added a `triggers` block to `aws_api_gateway_deployment` referencing the resource policy. This forces Terraform to create a new deployment whenever the policy changes, and updates the stage to point at it.

```hcl
triggers = {
  redeployment = sha1(jsonencode([
    aws_api_gateway_rest_api_policy.ip_restrict.policy
  ]))
}
```

**Lesson**

In API Gateway, changes to resource policies, authorizers, and certain settings do not take effect until the API is redeployed. Applying infrastructure changes through Terraform does not automatically redeploy the stage. Use the `triggers` block on the deployment resource to create an explicit link between configuration changes and redeployments. Without this, Terraform reports a successful apply while the live stage continues running the old configuration.

## Duplicate Deployments From Terraform State Drift

**Problem**

After adding a Terraform-managed CloudWatch log group, `terraform plan` proposed creating an API Gateway and DynamoDB table that were already deployed and in use. The AWS account contained two partial copies of the project: one named `aws-defence-*` and one named `aws-serverless-security-hardening-*`.

**Investigation**

`terraform state list` showed the state file tracked only the `aws-defence-*` Lambda, IAM role, and policy. Listing resources with the AWS CLI showed the working API, table, and Lambda all used the `aws-serverless-security-hardening-*` names, and none of them were in state. The `project_name` in `terraform.tfvars` had been changed at some point, and the live deployment had been created with a different state file than the one in the project folder.

**Root Cause**

Terraform only manages resources recorded in its state file. It does not scan AWS for resources that look like they belong to the configuration, because names are not reliable identifiers: some resources (such as REST APIs) allow duplicate names, and adopting a resource automatically would let Terraform modify or destroy infrastructure it did not create. With the state file stored locally and the project name changed, a second set of resources was created that this state file had no record of.

**Resolution**

Destroyed the stale `aws-defence-*` resources with `terraform destroy`, deleted the untracked copy with the AWS CLI, set a single `project_name` in `terraform.tfvars`, and rebuilt the full stack with one `terraform apply`. A follow-up `terraform plan` against an unchanged configuration is the check that state and AWS agree.

**Lesson**

The state file is the only link between Terraform code and real infrastructure. If it is local, lost, or duplicated, Terraform silently loses track of resources. Treat `project_name` as fixed once resources exist, make changes only through Terraform, and use a remote backend (S3 with state locking) so every machine uses the same state. When existing resources do need to be brought under management, use `terraform import` explicitly rather than expecting Terraform to discover them.
