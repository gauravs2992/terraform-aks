# Terraform AKS Test Pipeline

This repository provisions a small Azure Kubernetes Service (AKS) cluster for testing. The default Jenkins run creates the cluster, checks that its nodes become Ready, and attempts Terraform destroy in an `always` post action.

## Prerequisites

- A Linux Jenkins agent with Terraform 1.6+, Azure CLI, and kubectl installed.
- An Azure service principal with permission to create and delete a resource group, AKS cluster, and the related managed resources in the target subscription. Contributor at subscription scope is sufficient for this test setup.
- Jenkins credentials configured as:
  - `azure-service-principal`: Username with the service principal client ID and Password with its client secret.
  - `azure-subscription-id`: Secret text containing the subscription ID.
  - `azure-tenant-id`: Secret text containing the tenant ID.
- Azure quota and permission to create the configured VM size in the selected region.

## Jenkins Actions

Create a Pipeline job pointing to this repository and use the root `Jenkinsfile`. Select an action:

- `CREATE_AND_DESTROY` (default): create AKS, wait for Ready nodes, then always attempt cleanup. A cleanup failure marks the build as failed.
- `CREATE`: create and verify AKS, leaving it running.
- `DESTROY`: destroy resources tracked in the Terraform state from a previous `CREATE` run.

The Terraform state is local to the Jenkins workspace. Run separate `CREATE` and `DESTROY` builds on the same persistent job workspace; do not enable workspace cleanup between those runs. For agents with ephemeral workspaces, configure a remote Terraform backend before using separate create and destroy builds.

The defaults create one `Standard_D2s_v5` node in `eastus` on the AKS Free management tier. Azure compute and networking resources may still incur charges. The default action is intended to limit that exposure by tearing down resources after the smoke test. Override Terraform variables with `TF_VAR_<name>` environment variables when needed, for example `TF_VAR_location` or `TF_VAR_node_vm_size`.

## Local Use

Authenticate with Azure CLI or set the standard `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, and `ARM_TENANT_ID` environment variables, then run:

```sh
terraform init
terraform validate
terraform apply
terraform destroy
```