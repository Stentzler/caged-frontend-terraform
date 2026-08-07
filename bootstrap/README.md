# Remote-state bootstrap

This directory will contain the independent Terraform configuration that
creates the protected S3 state backend. It remains separate because the main
root module cannot create the backend that stores its own state.

The bootstrap implementation will provide encrypted, versioned, non-public S3
state with native S3 locking. Account-specific backend values stay in an
uncommitted configuration file; only `backend.hcl.example` is committed.
