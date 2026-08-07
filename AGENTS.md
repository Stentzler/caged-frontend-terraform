# Repository Instructions

## 1. Mission

This repository provisions the AWS infrastructure for the CAGED Next.js
frontend. Implement only the infrastructure approved in `SPEC.md`.

Read `SPEC.md` completely before planning or changing infrastructure. Treat it
as the product and architecture source of truth. When code, documentation, and
the specification disagree, stop and resolve the discrepancy instead of
silently choosing one.

## 2. Repository boundary

This repository owns Terraform for:

- Remote-state bootstrap and backend documentation.
- VPC, public subnet, routing, and security groups.
- One EC2 instance, EBS volume, Elastic IP, and instance role.
- Nginx bootstrap and baseline proxy configuration.
- ECR repository for `caged-frontend-next`.
- CloudFront distribution and cache behaviors.
- CloudFront-scoped AWS WAF rules.
- Optional Route 53 and ACM viewer-domain resources.
- SSM parameters and Systems Manager deployment wiring.
- GitHub OIDC deployment permissions.
- Basic infrastructure metrics and alarms.

Do not implement Next.js application code, Lambda code, API Gateway, CAGED ECS
processing, or DynamoDB tables in this repository.

## 3. Architecture invariants

Preserve these decisions unless the user explicitly approves a specification
change:

- Traffic flows through CloudFront and AWS WAF before reaching EC2.
- There is no Application Load Balancer.
- There is no NAT Gateway.
- One EC2 instance runs host Nginx and a loopback-bound Next.js container.
- Viewer traffic uses HTTPS.
- The MVP CloudFront-to-Nginx origin connection uses restricted HTTP.
- EC2 port 80 accepts traffic only from the AWS-managed CloudFront
  origin-facing prefix list.
- EC2 has no inbound SSH rule.
- Port 3000 is never publicly reachable.
- CloudFront adds a generated origin-verification header.
- Nginx rejects missing or invalid origin verification.
- WAF rate-limits qualifying POST requests to 10 per source IP per 60 seconds.
- Nginx applies an exact second-layer analytics POST limit using a trusted
  CloudFront viewer address.
- Next.js invokes Lambda directly with the EC2 instance role.
- No API Gateway resource or permission is introduced.
- The query Lambda contract remains unchanged.
- Infrastructure starts with a `dev` environment root and a `shared` root for
  explicitly account-level resources. Add an independent `prod` root only when
  production implementation begins; Terraform workspaces are not used for
  environment separation.

Do not introduce ALB, NAT, Redis, Kubernetes, ECS hosting, Lambda Function URLs,
API Gateway, or private endpoints as incidental improvements.

## 4. External contracts

The existing query Lambda is outside this repository. Accept its qualified
alias ARN through a variable and grant only `lambda:InvokeFunction` on that
resource.

The Lambda currently expects an API-Gateway-shaped event and returns an
API-Gateway-style envelope. The adapter belongs in `caged-frontend-next`; do not
change, reproduce, or reinterpret that payload in Terraform.

The future CBO Lambda is also external. Keep its ARN optional until it exists.
Never replace a missing ARN with wildcard Lambda permissions.

The frontend works with CBO occupational families, not individual occupation
codes. Infrastructure naming and documentation should use `cbo-family` or
`occupational-family` when the distinction matters.

## 5. Terraform organization

Keep `environments/dev` as a small composition root and add
`environments/prod` only with production implementation. Place reusable,
cohesive infrastructure domains in `modules/`, such as network, frontend host,
edge delivery, and observability. Keep account-level resources in
`environments/shared`.

Each module must own a meaningful resource domain with a clear interface; do
not create thin modules that merely rename a few resources.

Keep Terraform/provider constraints, providers, environment inputs, locals, and
outputs in each environment root. Keep module-specific inputs and outputs with
their module. Store bootstrap scripts and generated configuration under
`templates/`.

## 6. Terraform conventions

- Write beginner-friendly comments for every implemented Terraform block. The
  comments must explain the purpose and important trade-off, not merely restate
  the HCL syntax.
- Use descriptive snake_case Terraform identifiers.
- Use stable `for_each` keys rather than index-based `count` when resource
  identity matters.
- Add types, descriptions, and validation to public variables.
- Mark sensitive variables and values as sensitive, but remember that this does
  not remove them from state.
- Use locals for repeated names, tags, and policy fragments.
- Merge mandatory tags so callers cannot silently replace them.
- Prefer data sources for account, partition, Region, AMI, and managed prefix
  list information.
- Do not hard-code AWS account IDs, AMI IDs, availability zones, Lambda ARNs, or
  user-specific resource names.
- Avoid unnecessary explicit `depends_on`; rely on references where possible.
- Avoid provisioners. Never use `local-exec` or `remote-exec` for deployment.
- Keep user data idempotent and safe to run on replacement instances.
- Add lifecycle rules only when they express an intentional safety or ownership
  constraint.
- Do not use `ignore_changes` to conceal configuration drift.
- Do not use `-target` as a normal deployment mechanism.
- Preserve `.terraform.lock.hcl` and review provider changes deliberately.

### Component control plane

Each deployable infrastructure component must have a numeric `0` or `1` control
in the environment root's `component_controls.tf` file. Validate that each control
accepts only `0` or `1`, then use it to conditionally create the component's
module with `count`.

Gate cohesive components, not individual dependent resources. For example, a
single network control owns the VPC, subnet, routing, and security group
together. Setting a control from `1` to `0` proposes destruction of that
component, so it always requires a reviewed plan and explicit authorization.

## 7. Global-resource providers

CloudFront-scoped WAF resources and the optional CloudFront ACM certificate must
use an aliased `us-east-1` AWS provider. Regional resources use the primary
provider configured by `var.aws_region`.

Pass provider aliases explicitly if a child module is ever introduced. A
resource in the wrong Region is a correctness defect, not a harmless style
issue.

## 8. State safety

The main configuration uses protected remote S3 state and native S3 locking.
Do not commit backend credentials, access keys, state files, plan files, or real
backend configuration containing account-specific names.

Never commit:

- `.terraform/`
- `*.tfstate` or `*.tfstate.*`
- Saved binary plans
- Real secret-bearing `.tfvars`
- AWS credential files

Keep only sanitized examples such as `terraform.tfvars.example` and
`backend.hcl.example`.

Do not weaken bucket encryption, versioning, public-access blocks, state
locking, or least-privilege state access to simplify local execution.

## 9. Network and origin security

- Look up the AWS-managed CloudFront origin-facing prefix list instead of
  copying CIDR ranges.
- Never add `0.0.0.0/0` ingress to EC2 port 80, 443, 3000, or 22.
- Never expose the Next.js container beyond `127.0.0.1:3000`.
- Do not add SSH keys or an SSH ingress variable. Use Systems Manager.
- Require IMDSv2.
- Encrypt the GP3 root volume.
- Keep the Elastic IP as the stable public origin identity.
- Restrict outbound ports to what bootstrap and runtime require, while keeping
  DNS, HTTPS AWS APIs, operating-system updates, SSM, ECR, and Lambda usable.
- Keep the generated origin secret out of outputs, logs, examples, and comments.
- Store the origin secret as an SSM SecureString and render it only into a
  root-readable Nginx configuration.

The accepted HTTP origin path is an explicit MVP tradeoff. Do not claim that it
is end-to-end encrypted. If authentication, personal data, or administrative
operations enter scope, stop and request a security and architecture update.

## 10. Nginx rules

Nginx configuration belongs in a template, not an unreadable escaped Terraform
string.

The template must:

- Validate the CloudFront origin secret before proxying.
- Use a CloudFront-added viewer-address header for client identity.
- Avoid trusting viewer-controlled forwarding headers.
- Rate-limit analytics POST requests and return `429` on excess traffic.
- Exclude normal GET requests and static assets from the analytics limit.
- Forward the original host and HTTPS scheme to Next.js.
- Proxy only to the loopback Next.js port.
- Set explicit timeouts and a bounded request-body size.
- Hide the Nginx version and avoid diagnostic endpoints.
- Support a local health check used by deployment verification.

Any parsing of IPv4 and IPv6 viewer-address values must be tested. Do not group
all clients into one limit bucket when parsing fails; reject or handle malformed
trusted headers explicitly.

## 11. CloudFront and caching rules

- Redirect viewers from HTTP to HTTPS.
- Associate the WAF web ACL directly with the distribution.
- Cache `/_next/static/*` as immutable build assets.
- Use a bounded, query-aware policy for `/_next/image*`.
- Disable caching for the default dynamic behavior.
- Forward the cookies, query strings, and headers required by Next.js App Router
  and Server Actions.
- Allow POST to reach the origin.
- Never cache server-action responses or error responses for long periods.
- Add the origin-verification header through CloudFront configuration.
- Forward a trusted CloudFront viewer-address header for Nginx rate limiting.

Do not optimize cache keys by guesswork. When changing forwarded values, verify
locale routing, redirects, RSC navigation, Server Actions, and static build
assets.

## 12. WAF rules

The initial web ACL has one custom rate-based rule:

- Scope is `CLOUDFRONT`.
- Aggregation is by source IP.
- Evaluation window is 60 seconds.
- Default limit is 15.
- Scope-down matches HTTP POST.
- Blocked requests receive HTTP `429`.
- CloudWatch metrics and sampled requests are enabled.

Do not apply the rate rule to every GET request. Do not add paid managed rule
groups, Bot Control, CAPTCHA, or full WAF logging without an explicit cost and
scope decision.

AWS WAF is approximate. Preserve Nginx as the strict second layer and document
the distinction.

## 13. IAM rules

Use least privilege and resource-level permissions.

The EC2 instance role may receive only the required SSM, ECR pull, SSM parameter
read, logging, and qualified Lambda invocation permissions.

The GitHub OIDC deployment role must restrict trust to the expected owner,
`caged-frontend-next` repository, and approved ref or GitHub environment. Its
permissions are limited to the frontend ECR repository and controlled SSM
deployment operations.

Do not attach broad AWS managed policies when a small inline or customer-managed
policy can express the actual need. Never use wildcard Lambda resources because
the CBO Lambda does not yet exist.

Account-level resources such as the GitHub OIDC provider need an explicit
ownership switch or existing ARN input to prevent duplicates.

## 14. EC2 bootstrap and deployment

Target Ubuntu Server 24.04 LTS and resolve the AMI dynamically. Keep the
bootstrap script idempotent.

Bootstrap may install and configure Docker, Nginx, Systems Manager support, and
the minimal operating dependencies. It must not deploy a mutable `latest`
application image as an uncontrolled side effect.

Application releases are deployed from `caged-frontend-next` through GitHub
OIDC, ECR, and Systems Manager. The deployment command must use immutable image
identifiers, verify health, and retain a rollback path.

Terraform creates infrastructure; it does not build, push, or release the
application image.

## 15. Documentation synchronization

When a change affects configuration, behavior, operations, or cost, update all
affected sources in the same change:

- `SPEC.md` when requirements or architecture are intentionally changed.
- `README.md` for setup and operator instructions.
- Variable and output descriptions.
- `terraform.tfvars.example` or `backend.hcl.example`.
- Nginx and user-data templates.
- Tests and validation policy.

Do not edit `SPEC.md` merely to make an implementation deviation appear valid.
Architecture changes require explicit approval.

## 16. Testing and validation

Run the smallest relevant checks during development and the complete suite
before handoff.

Required final checks, when the tools are available, are:

- `terraform fmt -check -recursive`
- `terraform init -backend=false`
- `terraform validate`
- `tflint --recursive`
- `trivy config --exit-code 1 --severity HIGH,CRITICAL .`

Add focused Terraform tests or policy assertions for security-critical
invariants, especially:

- No SSH ingress.
- No public port 3000.
- CloudFront-only origin ingress.
- WAF CloudFront scope and POST rate rule.
- WAF association with CloudFront.
- Sensitive origin secret not output.
- Resource-scoped Lambda invocation.
- Restricted GitHub OIDC trust.
- All-or-nothing custom-domain resources.

If a tool is unavailable, report the missing validation; do not claim it passed.

## 17. Change safety

Inspection, formatting, validation, and speculative plans are allowed when they
fit the user's request. Cloud mutations require explicit authorization.

Never run any of the following unless the user explicitly requests the exact
operation and its scope is understood:

- `terraform apply`
- `terraform destroy`
- `terraform import`
- `terraform state rm`
- `terraform state mv`
- `terraform taint`
- AWS CLI create, update, or delete commands
- Manual console changes

Before proposing replacement of EC2, EIP, CloudFront, WAF, the state bucket, or
IAM/OIDC resources, call out the operational and security impact.

Never delete or recreate the state backend to fix an initialization problem.

## 18. Definition of done

A change is complete only when:

- It implements the requested behavior without violating `SPEC.md`.
- Naming, tags, variables, and outputs remain consistent.
- IAM and network access remain least-privilege.
- No secret or state artifact is committed or output.
- Formatting and validation pass.
- Relevant security checks pass.
- Templates remain idempotent and readable.
- Documentation and examples match the implementation.
- The handoff names any unverified cloud behavior, required manual value, cost
  impact, or external dependency.
