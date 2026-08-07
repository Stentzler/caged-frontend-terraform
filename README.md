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
