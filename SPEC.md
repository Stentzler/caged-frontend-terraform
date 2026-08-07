# CAGED Frontend Infrastructure Specification

## Document status

| Field | Value |
| --- | --- |
| Repository | `caged-frontend-terraform` |
| Version | 1.0 |
| Status | Approved for MVP implementation |
| Active environments | Development, with an account-level shared stack; production is added when its implementation begins |
| Infrastructure as code | Terraform |
| Application repository | `caged-frontend-next` |

## 1. Purpose

This repository provisions the AWS infrastructure required to run the CAGED
frontend. The frontend is a self-hosted Next.js application that invokes
existing AWS Lambda functions from the server runtime. Browser code must never
receive AWS credentials, Lambda ARNs, DynamoDB details, or direct access to an
AWS data service.

The infrastructure is intentionally cost-conscious. It uses CloudFront and AWS
WAF instead of an Application Load Balancer, and Nginx runs on the same EC2
instance as the Next.js container.

## 2. Product context

The frontend presents processed Novo CAGED employment statistics. The initial
application provides:

- A Home page with country or state, CBO occupational family, and optional
  month-range filters.
- Monthly admissions, dismissals, net balance, turnover, and average admission
  salary returned by the existing query Lambda.
- A list of CBO occupational families returned by a future CBO Lambda.
- Portuguese and English interfaces.
- An About page describing the source, methodology, experimental nature, and
  lack of government affiliation.

The frontend works only with CBO family values. It must use `family_code` and
`family_title`; individual occupation codes and `ocupation_title` are outside
the frontend contract.

## 3. Locked architecture decisions

The following decisions are fixed for the MVP:

1. The public entry point is Amazon CloudFront.
2. AWS WAF is associated with the CloudFront distribution.
3. No Application Load Balancer is provisioned.
4. A single EC2 instance runs Nginx and the Next.js container.
5. The EC2 origin is public for cost-efficient outbound AWS API access, but
   inbound application traffic is restricted to CloudFront origin-facing
   addresses.
6. CloudFront sends a generated secret origin header, and Nginx rejects requests
   that do not contain the expected value.
7. CloudFront provides viewer HTTPS. The MVP origin connection is HTTP because
   ACM certificates cannot be installed directly on EC2 and a private origin
   would require additional outbound networking infrastructure.
8. Nginx proxies only to a Next.js process bound to the loopback interface.
9. Next.js invokes Lambda synchronously with the AWS SDK and temporary
   credentials from the EC2 instance role.
10. API Gateway is not provisioned or called by this frontend.
11. The existing query Lambda remains unchanged. Its API-Gateway-shaped event
    and response envelope are adapted by `caged-frontend-next`.
12. When dates are omitted, Next.js follows the query Lambda contract and
    requests only the latest available month. Infrastructure does not impose
    date rules.
13. The WAF rate limit is 15 analytics submissions per source IP in a 60-second
    evaluation window.
14. Nginx provides a second, exact per-client rate limit for analytics POST
    requests.
15. CloudFront pay-as-you-go pricing is used for the initial implementation.
    The flat-rate Free plan is not assumed because it limits custom caching and
    private-origin capabilities.
16. Development uses an independent Terraform root and state. An explicit
    shared root owns account-level resources such as a GitHub OIDC provider.
    Production will receive its own root and state when implementation begins;
    Terraform workspaces are not used for environment separation.

## 4. High-level request flow

1. A visitor connects to the CloudFront distribution over HTTPS.
2. AWS WAF evaluates the request before it reaches the origin.
3. Static Next.js assets may be served from the CloudFront cache.
4. Dynamic requests are forwarded to the EC2 origin with the secret origin
   header and CloudFront viewer-address information.
5. The EC2 security group accepts origin traffic only from the AWS-managed
   CloudFront origin-facing prefix list.
6. Nginx verifies the origin secret and applies the local rate limit.
7. Nginx proxies the request to Next.js on `127.0.0.1:3000`.
8. Next.js invokes the required Lambda with the EC2 instance role.
9. The Lambda reads its DynamoDB data and returns its existing contract.
10. Next.js parses the Lambda response and renders the result.

## 5. Repository responsibilities

### 5.1 This repository owns

- Terraform version and provider constraints.
- Remote Terraform state bootstrap and backend documentation.
- VPC, subnet, route table, internet gateway, and security groups.
- EC2 instance, encrypted EBS volume, Elastic IP, IAM instance profile, and
  bootstrap configuration.
- ECR repository for the Next.js image.
- Nginx installation and baseline reverse-proxy configuration.
- CloudFront distribution, cache behaviors, origin headers, and viewer TLS.
- AWS WAF web ACL and rate-based rule.
- Optional Route 53 and ACM resources for a custom viewer domain.
- SSM Parameter Store values owned by this infrastructure.
- GitHub OIDC deployment role and least-privilege deployment permissions.
- Basic CloudWatch metrics, alarms, and resource tags.
- Terraform outputs consumed by deployment workflows.

### 5.2 This repository does not own

- Next.js pages, components, server actions, translations, or application tests.
- Lambda implementation or deployment.
- API Gateway.
- CAGED processing ECS resources.
- DynamoDB tables used by the CAGED backend.
- Changes to the existing query Lambda request or response contract.
- Creation of the future CBO Lambda.
- User authentication, authorization, or storage of personal information.

## 6. Expected repository structure

| Path | Responsibility |
| --- | --- |
| `AGENTS.md` | Repository-specific implementation rules |
| `SPEC.md` | Approved infrastructure requirements |
| `README.md` | Human setup, deployment, operations, and cost documentation |
| `environments/shared/` | Account-level resources, including optional GitHub OIDC provider ownership |
| `environments/dev/` | Development composition root, state configuration, inputs, and outputs |
| `environments/prod/` | Future production composition root, added when production implementation begins |
| `modules/network/` | VPC, subnet, routes, internet gateway, and CloudFront-only origin security group |
| `modules/frontend_host/` | EC2, EBS, Elastic IP, host identity, SSM parameters, and Nginx bootstrap wiring |
| `modules/container_registry/` | Application container repository and lifecycle policy |
| `modules/edge_delivery/` | CloudFront, global WAF, origin configuration, cache policies, and optional viewer domain |
| `modules/github_deployment/` | Environment-scoped GitHub deployment role and least-privilege permissions |
| `modules/observability/` | CloudWatch alarms and optional notification wiring |
| `templates/user-data.sh.tftpl` | Idempotent Ubuntu instance bootstrap |
| `templates/nginx.conf.tftpl` | Nginx proxy, origin validation, and rate limiting |
| `bootstrap/` | Independent S3 backend bootstrap configuration |
| `environments/*/*.tfvars.example` | Safe environment example values with no credentials or secrets |

Environment roots should contain composition and environment-specific values
only. Reusable modules own coherent infrastructure domains with explicit input
and output interfaces; thin pass-through modules are not allowed.

## 7. Terraform and state requirements

### 7.1 Versioning

- Declare a minimum supported Terraform version.
- Constrain the AWS and Random providers to compatible major versions.
- Commit `.terraform.lock.hcl`.
- Pin CI tool versions rather than downloading unbounded latest versions.

### 7.2 Providers

Two AWS provider configurations are required:

- The primary provider uses `var.aws_region`, which must be the Region of the
  existing query Lambda and future CBO Lambda.
- An aliased `us-east-1` provider owns CloudFront-scoped WAF and the optional
  CloudFront ACM certificate.

No provider may contain hard-coded credentials, account IDs, or personal AWS
profiles.

### 7.3 Remote state

The main root uses an S3 backend with:

- Bucket versioning.
- Server-side encryption.
- Public access blocked.
- Least-privilege access.
- Native S3 state locking with `use_lockfile`.
- A stable development key such as `caged-frontend/dev/terraform.tfstate`.
  Production receives its own key when that environment is introduced.

The backend bucket is bootstrapped separately because Terraform cannot create
the backend that stores its own initial state. Backend names and Region are
provided through backend configuration, not hard-coded in the main root.

No secret may be exposed through an output. Generated secrets still exist in
Terraform state, so access to the state bucket must be tightly restricted.

## 8. Naming and tagging

Resource names use the pattern `caged-frontend-{environment}-{resource}` where
the AWS service permits it.

Every taggable resource must receive at least:

| Tag | Value |
| --- | --- |
| `Project` | `caged-frontend` |
| `Environment` | Value of `var.environment` |
| `ManagedBy` | `terraform` |
| `Repository` | `caged-frontend-terraform` |

Optional business tags such as `Owner` and `CostCenter` are accepted through a
map variable and merged with the mandatory tags. Mandatory tags cannot be
silently overridden.

## 9. Network specification

### 9.1 VPC

Provision one dedicated VPC containing:

- DNS support and DNS hostnames enabled.
- One public subnet for the single MVP EC2 instance.
- One internet gateway.
- One public route table with an IPv4 default route to the internet gateway.
- No NAT Gateway.
- No Application Load Balancer.
- No inbound SSH rule.

The single-subnet design is intentional because one EC2 instance remains the
MVP availability boundary. A multi-AZ design is deferred until multiple
application instances are introduced.

### 9.2 EC2 security group

Inbound rules must allow:

- TCP port 80 only from the AWS-managed IPv4 CloudFront origin-facing prefix
  list.
- IPv6 origin-facing access only when both the VPC and instance origin are
  explicitly upgraded to IPv6.

Inbound rules must not allow application ports from `0.0.0.0/0`, and port 3000
must never be reachable outside the instance.

Outbound rules must support DNS and HTTPS access required for Lambda, ECR, SSM,
package installation, and operating-system updates. Avoid adding broad outbound
ports that are not required.

### 9.3 Stable origin

Associate one Elastic IP with the EC2 instance. CloudFront must use a publicly
resolvable origin hostname. When a custom domain is available, create a
dedicated origin record pointing to the Elastic IP. Otherwise use the EC2
public DNS name and allow Terraform to update the distribution if the instance
is replaced.

## 10. EC2 specification

The instance must:

- Use the latest supported Ubuntu Server 24.04 LTS image resolved from an AWS or
  Canonical public parameter instead of a hard-coded AMI ID.
- Use an instance type supplied by a validated variable.
- Use an encrypted GP3 root volume with configurable size.
- Require IMDSv2 tokens.
- Disable public SSH access.
- Register with AWS Systems Manager.
- Run Nginx as a host service.
- Run the Next.js image as a Docker container bound to `127.0.0.1:3000`.
- Restart Nginx and the application container after reboot.
- Apply an idempotent bootstrap script suitable for a replacement instance.
- Avoid embedding AWS credentials or application secrets in user data.

Detailed EC2 monitoring remains disabled by default to avoid unnecessary MVP
cost. Standard EC2 and status-check metrics remain available.

## 11. Nginx specification

Nginx is the only process accepting CloudFront origin requests. Its generated
configuration must:

- Listen on port 80 for origin traffic.
- Return `403` when the expected CloudFront origin-verification header is absent
  or incorrect.
- Receive a trusted CloudFront viewer-address header selected by the CloudFront
  origin-request policy.
- Derive a normalized viewer IP from the trusted header for local rate limiting.
- Never trust an arbitrary viewer-supplied `X-Forwarded-For` value as the rate
  limit identity.
- Apply a 10-requests-per-minute limit to analytics POST submissions, with a
  small documented burst allowance and HTTP `429` on excess requests.
- Avoid applying the analytics rate limit to static assets and normal GET page
  navigation.
- Proxy dynamic traffic to `http://127.0.0.1:3000`.
- Preserve the viewer host and communicate the original HTTPS scheme to Next.js
  with trusted proxy headers.
- Set practical proxy connection, response, and body-size limits.
- Expose no directory listing, Nginx status page, or server-version header.
- Provide a health path suitable for local deployment verification.

The origin secret must be generated by Terraform, stored as an SSM SecureString,
and delivered to the root-owned Nginx configuration during bootstrap or an SSM
configuration command. It must not appear in Terraform outputs, examples, logs,
or documentation.

## 12. CloudFront specification

### 12.1 Distribution

Provision one enabled CloudFront distribution with:

- IPv6 viewer support enabled unless a verified dependency prevents it.
- Viewer protocol policy redirecting HTTP to HTTPS.
- Modern TLS policy.
- HTTP/2 and HTTP/3 enabled when supported by the chosen provider version.
- Compression enabled.
- A custom error strategy that does not cache origin `500`, `502`, `503`, or
  `504` responses for long periods.
- A descriptive comment and mandatory project tags.
- The WAF web ACL associated through `web_acl_id`.

### 12.2 Origin

The custom origin points to the Nginx EC2 hostname and uses:

- HTTP-only origin protocol for the MVP.
- Port 80.
- A generated secret custom origin header.
- Conservative connection attempts and timeouts suitable for server-rendered
  Next.js requests.

The HTTP origin exception is accepted only because the MVP is read-only,
contains no login flow, and processes no personal or confidential user data.
Adding authentication, personal data, or administrative operations requires a
separate security review and HTTPS or private connectivity to the origin.

### 12.3 Cache behaviors

At minimum, configure:

| Behavior | Caching | Methods | Purpose |
| --- | --- | --- | --- |
| `/_next/static/*` | Long-lived, immutable | GET and HEAD | Build assets |
| `/_next/image*` | Query-aware bounded cache | GET and HEAD | Next image optimization |
| Default | Disabled | All methods required for Next.js POST support | SSR, navigation, and server actions |

The default behavior must forward the cookies, query strings, and headers needed
by Next.js App Router and Server Actions. It must preserve enough host and
origin information for Next.js origin checks and redirects to work behind both
CloudFront and Nginx.

Do not cache POST responses, personalized responses, errors, or server-action
responses. Cache configuration must be covered by an integration checklist in
the README.

### 12.4 Custom viewer domain

Custom-domain support is optional and controlled by input variables.

When enabled:

- Create or reference an ACM certificate in `us-east-1`.
- Validate the certificate through Route 53 DNS when a hosted-zone ID is
  supplied.
- Add the CloudFront alias.
- Create an alias record pointing the viewer domain to CloudFront.

When disabled, output the CloudFront distribution domain and do not create
partial certificate or DNS resources.

## 13. AWS WAF specification

Create one `CLOUDFRONT`-scope web ACL with the aliased `us-east-1` provider.

The MVP web ACL contains one rate-based rule:

| Setting | Required value |
| --- | --- |
| Aggregation key | Source IP |
| Evaluation window | 60 seconds |
| Limit | 15 requests |
| Scope-down | HTTP method `POST` |
| Action | Block |
| Custom response | HTTP `429` |
| Metrics | Enabled |
| Sampled requests | Enabled |

The rule intentionally limits all POST requests because the MVP has only one
public form submission that can invoke the query Lambda. If the frontend later
introduces another POST workflow, update the scope-down statement to a stable
analytics path or header before deploying that workflow.

AWS WAF rate limiting is approximate. Nginx supplies the stricter origin-level
limit. Lambda reserved concurrency remains owned by the Lambda infrastructure
and is not configured here.

Full WAF logging and managed rule groups are deferred to control cost. Metrics
and sampled requests must still be available for tuning and troubleshooting.

## 14. IAM specification

### 14.1 EC2 instance role

The EC2 instance role receives only the permissions required to:

- Register and operate through Systems Manager.
- Pull the frontend image from its specific ECR repository.
- Read the specific SSM parameters required by Nginx and the Next.js runtime.
- Invoke the qualified production alias ARN of the existing query Lambda.
- Invoke the qualified production alias ARN of the future CBO Lambda after its
  ARN is supplied.
- Publish explicitly configured application or agent logs when logging is
  enabled.

Do not attach `AdministratorAccess`, `PowerUserAccess`, `AWSLambdaRole`, or broad
wildcard resource policies when resource-level permissions are supported.

The existing query Lambda is invoked directly. No API Gateway permissions or
resources belong in this repository.

### 14.2 GitHub deployment role

Provision or integrate with GitHub OIDC. The trust policy must be restricted to:

- The expected GitHub organization or owner.
- The `caged-frontend-next` repository.
- The approved deployment branch or protected environment.

The deployment role may:

- Authenticate and push images to the specific frontend ECR repository.
- Send an approved SSM deployment document or command to EC2 instances carrying
  the expected project and environment tags.
- Read deployment status.

It must not receive general EC2, IAM, Lambda, DynamoDB, or Terraform state
administration permissions.

An existing account-level GitHub OIDC provider may be supplied. The repository
must not create a duplicate provider when one already exists.

## 15. ECR specification

Create one private ECR repository for `caged-frontend-next` with:

- Encryption at rest.
- Immutable release tags.
- Image scanning enabled through the supported ECR scanning configuration.
- A lifecycle policy that retains a small, documented number of recent release
  images and removes untagged images after a short grace period.
- A repository policy only when cross-account or additional service access is
  actually required.

The Terraform repository creates ECR but does not build or deploy the Next.js
image.

## 16. Application deployment contract

The `caged-frontend-next` deployment workflow is expected to:

1. Authenticate to AWS using GitHub OIDC.
2. Build a production Next.js Docker image for the EC2 architecture.
3. Tag the image with an immutable commit SHA or release identifier.
4. Push the image to the Terraform-managed ECR repository.
5. Use Systems Manager to run the controlled deployment command on EC2.
6. Pull the immutable image.
7. Start a replacement container bound only to `127.0.0.1:3000`.
8. Verify the local health endpoint.
9. Keep or restore the previous known image if health verification fails.
10. Report deployment status without opening SSH.

Terraform must output the non-secret identifiers required by this workflow.
Terraform must not run application deployment through `local-exec`,
`remote-exec`, or provisioners.

## 17. Lambda integration contract

This repository accepts qualified Lambda ARNs as inputs and grants invocation
permissions. It does not interpret Lambda payloads.

The frontend application must preserve these external facts:

- The existing query Lambda expects an event containing
  `queryStringParameters` with the camelCase parameters documented in
  `caged-query-lambda`.
- Direct invocation returns an API-Gateway-style envelope containing
  `statusCode`, `headers`, and a JSON string in `body`.
- Because API Gateway is bypassed, the body uses the Lambda's internal
  snake_case field names.
- Frontend logic owns conversion to application-facing camelCase types.
- Lambda `400`, `503`, `500`, SDK errors, throttles, and `FunctionError` must be
  handled by the frontend adapter.
- CBO Lambda input and output remain a dependency until that repository defines
  its contract.

The future CBO Lambda must return unique occupational families. The frontend
must not receive or deduplicate individual occupation rows.

## 18. Configuration variables

At minimum, expose typed and validated variables for:

| Variable | Requirement |
| --- | --- |
| `project_name` | Default `caged-frontend` |
| `environment` | Default MVP environment name; validated identifier |
| `aws_region` | Same Region as the invoked Lambdas |
| `vpc_cidr` | Valid non-overlapping IPv4 CIDR |
| `public_subnet_cidr` | Valid subnet inside the VPC CIDR |
| `availability_zone` | Optional explicit AZ in the primary Region |
| `instance_type` | Validated non-empty EC2 instance type |
| `root_volume_size_gib` | Positive bounded GP3 size |
| `query_lambda_alias_arn` | Qualified ARN of the existing query Lambda |
| `cbo_lambda_alias_arn` | Optional until the CBO Lambda exists |
| `github_owner` | Owner used in OIDC trust conditions |
| `github_repository` | Default `caged-frontend-next` |
| `github_deployment_ref` | Approved branch or environment subject |
| `github_oidc_provider_arn` | Optional existing provider ARN |
| `create_github_oidc_provider` | Explicit account-level ownership switch |
| `enable_custom_domain` | Controls viewer ACM and Route 53 resources |
| `viewer_domain_name` | Required only when custom domain is enabled |
| `route53_hosted_zone_id` | Required when Terraform manages DNS validation |
| `cloudfront_price_class` | Defaults to a class that includes South America |
| `waf_rate_limit` | Default and minimum `15` |
| `waf_evaluation_window_seconds` | Default `60`; restricted to AWS-supported values |
| `common_tags` | Additional non-conflicting resource tags |

Secret values are generated or read securely and must not be accepted through a
committed `tfvars` file.

## 19. Required outputs

Output only non-secret values required for operation and deployment:

- CloudFront distribution ID.
- CloudFront distribution domain.
- Effective viewer URL.
- ECR repository URL and ARN.
- EC2 instance ID.
- EC2 Elastic IP for operations, clearly marked as an origin that must not be
  used by visitors.
- SSM deployment target tag or instance identifier.
- GitHub deployment role ARN.
- Query Lambda alias ARN used by the instance policy.
- CBO Lambda alias ARN when configured.
- WAF web ACL ARN.

Do not output the origin secret, SSM SecureString value, temporary credentials,
or rendered user data.

## 20. Observability and operations

The MVP must provide:

- CloudFront standard metrics.
- WAF rate-rule metrics and sampled requests.
- EC2 status-check alarms.
- An optional configurable CPU alarm.
- Nginx and application logs available locally through Systems Manager.
- A documented procedure for checking the application health and current image.
- A documented procedure for rotating the origin secret.
- A documented procedure for replacing the EC2 instance and reassociating the
  Elastic IP.

Full CloudFront, WAF, and centralized Nginx access logging are deferred unless a
costed logging destination is explicitly approved.

## 21. Security invariants

Implementation must preserve all of the following:

- Browser code receives no AWS credentials or Lambda identifiers.
- EC2 has no inbound SSH access.
- The Next.js container is not bound to a public interface.
- EC2 application ingress is limited to CloudFront origin-facing addresses.
- Nginx rejects requests without the CloudFront origin secret.
- Viewer HTTPS is mandatory.
- WAF and Nginx rate limits are both enabled for analytics POST requests.
- IAM uses temporary role credentials and resource-scoped permissions.
- Terraform state is encrypted, versioned, locked, and non-public.
- Secrets never appear in outputs, example variable files, logs, or committed
  source.
- API Gateway, DynamoDB, and Lambda implementations are not managed here.
- No destructive infrastructure action is automated without an explicit,
  reviewed deployment decision.

## 22. Cost expectations

For a low-traffic MVP, the delivery and protection layer is expected to contain:

- One EC2 instance and one encrypted GP3 volume.
- One public IPv4 address for the EC2 origin.
- CloudFront pay-as-you-go request and transfer usage.
- One WAF web ACL and one custom rate rule.
- ECR storage for a limited number of images.
- Minimal CloudWatch alarm and metric usage.

There is no ALB, NAT Gateway, provisioned concurrency, or managed Redis cost.
The README must include an estimate for the selected AWS Region and explain
which items are fixed versus usage-based.

## 23. Validation requirements

Every implementation change must pass, as applicable:

- `terraform fmt -check -recursive`
- Terraform initialization without silently changing backend ownership.
- `terraform validate`
- `tflint --recursive`
- `trivy config` with a failing exit code for actionable high-severity findings.
- Focused Terraform tests or policy checks for critical conditionals.

Critical automated assertions should cover:

- No SSH ingress.
- No public ingress to port 3000.
- EC2 port 80 source is the CloudFront managed prefix list.
- WAF uses CloudFront scope, a 60-second window, and the configured minimum rate.
- The WAF rule scopes to POST.
- WAF is associated with the CloudFront distribution.
- The origin secret is marked sensitive and not output.
- The EC2 role can invoke only the configured Lambda aliases.
- The GitHub role trust is restricted to the expected repository and ref.
- Custom-domain resources are created together or not at all.

## 24. Acceptance criteria

The infrastructure MVP is complete when:

1. Terraform can bootstrap or connect to its protected remote state.
2. A plan from a clean checkout is deterministic and contains no unexpected
   replacement after a second plan.
3. CloudFront serves the Next.js application over HTTPS.
4. Direct requests to the EC2 origin are rejected at the network layer when
   they do not originate from CloudFront.
5. Requests routed through another CloudFront distribution without the secret
   origin header are rejected by Nginx.
6. Static Next.js build assets are cached while dynamic and POST responses are
   not cached.
7. The sixteenth qualifying analytics POST from one IP within the WAF evaluation
   window is rate-limited near the configured threshold, acknowledging WAF's
   approximate behavior.
8. Nginx enforces its exact local request limit using the trusted viewer address.
9. The Next.js runtime can invoke the configured query Lambda alias.
10. The instance has no static AWS credential files and uses its IAM role.
11. GitHub can push an immutable image and deploy it with Systems Manager without
    SSH.
12. A failed container health check leaves or restores a known working version.
13. Terraform outputs contain no origin secret or credentials.
14. Required validation and security checks pass.
15. README documentation explains deployment, rollback, cost, secret rotation,
    and the accepted HTTP origin tradeoff.

## 25. Deferred work

The following items are explicitly outside the MVP:

- Application Load Balancer.
- Auto Scaling Group and multiple EC2 instances.
- CloudFront private VPC origin.
- NAT Gateway and paid interface VPC endpoints.
- HTTPS between CloudFront and Nginx.
- CloudFront flat-rate plan migration.
- Full WAF managed rule groups and bot control.
- Centralized full access logs.
- Blue/green or canary infrastructure deployment.
- Disaster recovery across Regions.
- City-filter-specific infrastructure.
- Authentication or user-specific data.

Deferred items require a specification update before implementation.

## 26. External dependencies

Implementation depends on:

- A qualified alias ARN for `caged-query-lambda`.
- The query Lambda and EC2 being deployed in the same AWS Region.
- A future qualified alias ARN and contract for the CBO Lambda.
- A production image from `caged-frontend-next`.
- A domain and Route 53 hosted zone only if a custom viewer domain is enabled.
- GitHub repository and branch details for OIDC trust.

Missing optional dependencies must produce a clear Terraform validation or a
deliberately disabled resource, never a broad placeholder permission.

## 27. References

- Query Lambda contract: <https://github.com/Stentzler/caged-query-lambda/blob/main/README.md>
- AWS WAF protected resources: <https://docs.aws.amazon.com/waf/latest/developerguide/how-aws-waf-works-resources.html>
- AWS WAF rate-based rules: <https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based.html>
- CloudFront custom origins: <https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html>
- CloudFront origin-facing prefix list: <https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/LocationsOfEdgeServers.html>
- CloudFront pricing: <https://aws.amazon.com/cloudfront/pricing/>
- AWS WAF pricing: <https://aws.amazon.com/waf/pricing/>
