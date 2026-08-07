# CAGED Frontend Terraform

Terraform infrastructure for the CAGED Next.js frontend MVP. The approved
architecture is CloudFront and AWS WAF in front of one EC2 instance running
host Nginx and a loopback-bound Next.js container.

## Structure

- `environments/shared/`: explicitly account-level resources, including GitHub
  OIDC provider ownership.
- `environments/dev/`: the active infrastructure composition root and its
  independent Terraform state.
- `environments/prod/`: a future independent root, added with production
  implementation rather than as empty placeholders.
- `modules/`: cohesive reusable infrastructure domains.
- `templates/`: idempotent EC2 user data and readable Nginx configuration.
- `bootstrap/`: standalone remote-state backend bootstrap configuration.

This follows the backend repository's environment/module separation while
keeping this frontend's modules domain-sized rather than creating thin wrappers.

See `SPEC.md` for the approved architecture and `AGENTS.md` for implementation
and validation rules.

## Frontend request flow

The public edge components in this diagram are implemented in the next module;
the EC2 origin and its Nginx safeguards are already defined.

```mermaid
flowchart LR
  visitor[Visitor's browser]
  cloudfront[CloudFront\nHTTPS, cache rules]
  waf[AWS WAF\n15 POSTs/IP/minute]
  security_group[EC2 security group\nport 80: CloudFront prefix list only]
  nginx[Nginx on EC2\norigin verification + rate limit]
  nextjs[Next.js container\n127.0.0.1:3000]
  lambda[Query Lambda\nexternal backend infrastructure]
  dynamodb[(DynamoDB\nexternal backend infrastructure)]

  visitor -->|HTTPS request| cloudfront
  cloudfront --> waf
  waf -->|allowed request + trusted headers| security_group
  security_group --> nginx
  nginx -->|loopback only| nextjs
  nextjs -->|AWS SDK with EC2 role| lambda
  lambda --> dynamodb
  dynamodb --> lambda
  lambda --> nextjs
  nextjs --> nginx
  nginx --> cloudfront
  cloudfront -->|HTTPS response| visitor
```

### Why the origin-verification header exists

The EC2 security group is the first protection: port 80 accepts connections
only from AWS's managed CloudFront origin-facing prefix list. Nginx adds a
second protection. Terraform generates a random value, stores it as an SSM
SecureString, and Nginx reads it locally during EC2 bootstrap. The value is not
an output, not committed to Git, and not placed into the Terraform-rendered
user-data script.

When we create CloudFront, its origin configuration will add that same value as
the private `X-Caged-Origin-Verify` header on requests sent to EC2. Nginx
returns `403` if the header is missing or wrong, before proxying to Next.js.
So even another CloudFront distribution—or someone who somehow reaches the
origin network address—cannot use the origin without knowing the generated
secret. The header protects the **CloudFront-to-origin** hop; visitors never
see it and do not send it themselves.

## Remote state

The standalone `bootstrap/` root creates the protected S3 state bucket. After
bootstrapping, initialize the development root with the generated bucket name
and the uncommitted `environments/dev/backend.hcl` configuration. Native S3
lockfiles are enabled; DynamoDB locking is not used.

## Team setup: development environment

Every developer and CI runner must initialize the development root against the
shared S3 backend before using Terraform. This lets Terraform see and lock the
same state for every team member.

### Prerequisites

- Terraform 1.10 or newer.
- AWS credentials for the intended account and Region.
- IAM permission to read and write the development state object and lockfile,
  plus the least-privilege infrastructure permissions assigned to the role.
- The shared backend bucket name from the team's approved onboarding channel.

### First-time setup

1. Clone the repository.
2. Create a local backend configuration from the committed example:

   ```bash
   cp environments/dev/backend.hcl.example environments/dev/backend.hcl
   ```

3. Replace the placeholder `bucket` value with the shared state-bucket name.
   Do not commit `backend.hcl`; it is ignored intentionally.
4. Initialize the development root:

   ```bash
   terraform -chdir=environments/dev init -backend-config=backend.hcl
   ```

5. Confirm Terraform can read the shared state without changing infrastructure:

   ```bash
   terraform -chdir=environments/dev plan
   ```

After initialization, Terraform records the backend locally under the ignored
`.terraform/` directory. Normal `plan`, `apply`, and `state` commands then use
the shared S3 state automatically.

## Backend Lambda contract

The query Lambda is owned by `caged-aws-iac`, not by this repository. For now,
the development root receives its qualified alias ARN from the ignored local
`environments/dev/terraform.tfvars` file. The value is currently available as
the backend root output named `query_alias_arn`.

```hcl
# environments/dev/terraform.tfvars -- ignored by Git
query_lambda_alias_arn = "arn:aws:lambda:us-east-1:123456789012:function:caged-dev-query:dev"
```

Use an alias ARN rather than a plain function ARN so the future EC2 role is
limited to an intentional backend release. This identifier is not a secret,
but the local file stays uncommitted because it is account-specific.

Later, the backend repository can publish this ARN to a non-secret AWS Systems
Manager Parameter. This frontend root can then read only that parameter instead
of receiving a local value, without granting it access to the backend's full
Terraform state.

### Safe daily workflow

Always review the shared-state plan before changing infrastructure:

```bash
terraform -chdir=environments/dev plan
terraform -chdir=environments/dev apply
```

Only run `apply` after the plan is reviewed and the change is authorized. S3
native lockfiles prevent simultaneous applies, but they do not replace code
review or least-privilege IAM permissions.

## Component controls

`environments/dev/component_controls.tf` contains numeric `0`/`1` controls for each
deployable component. A value of `1` creates the component; `0` proposes its
destruction on the next approved apply. Controls gate whole modules, not their
individual dependent resources, so the VPC, subnet, routing, and security group
are switched together. Always run and review `terraform plan` after changing a
control.

Controls also enforce their prerequisites during input validation. For example,
`enable_frontend_host = 1` requires both `enable_network = 1` and
`enable_container_registry = 1`; Terraform reports a fatal validation error for
an invalid combination, so it cannot be applied. Terraform may still display a
partial plan for independent components before reporting that error.

### Frontend host identity

`enable_frontend_host` creates the IAM role, instance profile, one EC2 origin,
and its stable Elastic IP as one component. The role grants only Systems
Manager Session Manager access, pull access to this project's ECR repository,
and direct invocation of the configured query Lambda alias.

The host now uses an encrypted GP3 root volume, IMDSv2, no SSH key, and an
Elastic IP reserved only for the future CloudFront origin. Nginx accepts the
origin request only when the network source is CloudFront and CloudFront sends
the generated verification header. It also requires the trusted
`CloudFront-Viewer-Address` header and applies an exact 15-per-minute rate
limit to POST requests, returning `429` when the small burst allowance is
exceeded. CloudFront configuration to send these headers is the next edge
delivery step.

## Frontend image retention

The private ECR repository stores immutable frontend release images. Its
lifecycle policy permanently retains the three newest tagged images for
rollback and expires untagged images after three days to control storage cost.
Terraform does not build or push images; the frontend deployment workflow does
that after the repository is available.

## Edge protection

`enable_edge_delivery` creates the CloudFront-scoped WAF foundation in
`us-east-1`. Its single rule tracks source IP addresses, evaluates only POST
requests over 60 seconds, and returns `429` after 15 requests. CloudWatch
metrics and sampled requests are enabled; CloudFront itself is added in the
next edge-delivery increment and will attach this web ACL.
