# IAC Terraform Workshop

## Why do we need Terraform Cloud (or another backend) when we use CI/CD?

Because terraform needs to remember which resources are created to destroy them later. The backend (in our case a manually created s3 bucket) saves some metadata and `tofu init` uses the backend to recover the existing config and then update it in case of an action.

