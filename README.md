# Terraform AKS Test Pipeline

This repository provisions a small Azure Kubernetes Service (AKS) cluster for testing. Terraform state is stored in an Azure Blob container. The default Jenkins run creates the cluster, checks that its nodes become Ready, and then destroys the cluster and its dedicated state-storage resource group.

## Prerequisites

- A Linux Jenkins agent with Terraform 1.6+, Azure CLI, and kubectl installed.
- An Azure service principal with permission to create and delete resource groups, storage accounts, AKS clusters, and their related managed resources in the target subscription. Contributor at subscription scope is sufficient for this test setup.
- Jenkins credentials configured as:
  - `azure-service-principal`: Username with the service principal client ID and Password with its client secret.
  - `azure-subscription-id`: Secret text containing the subscription ID.
  - `azure-tenant-id`: Secret text containing the tenant ID.
- Azure quota and permission to create the configured VM size in the selected region.

## Jenkins Actions

Create a Pipeline job pointing to this repository and use the root `Jenkinsfile`. Set `STATE_STORAGE_ACCOUNT` to a globally unique name containing 3-24 lowercase letters or numbers. The account and container are created by the pipeline in `STATE_RESOURCE_GROUP` (`rg-aks-terraform-state` by default). The resource group is dedicated to this test and is deleted after successful destroy. Select an action:

- `CREATE_AND_DESTROY` (default): create the state storage and AKS, wait for Ready nodes, then always attempt cleanup. If AKS destroy fails, state storage is retained for recovery. After successful AKS destroy, its state-storage resource group is deleted.
- `CREATE`: create state storage, then create and verify AKS, leaving both in place for a later `DESTROY` run.
- `DESTROY`: use the same `STATE_STORAGE_ACCOUNT` and `STATE_RESOURCE_GROUP` values from the `CREATE` run, destroy AKS using the remote state, then delete the state-storage resource group.

The state account contains the Terraform state blob `tfstate/aks-test.tfstate`. Do not share the state account or resource group with other Terraform deployments: the `DESTROY` action removes the entire state resource group after the AKS destroy succeeds. If AKS destroy fails, state storage remains available so the destroy can be retried.

The defaults create one `Standard_D2s_v5` node in `eastus` on the AKS Free management tier. Azure compute and networking resources may still incur charges. The default action is intended to limit that exposure by tearing down resources after the smoke test. Override Terraform variables with `TF_VAR_<name>` environment variables when needed, for example `TF_VAR_location` or `TF_VAR_node_vm_size`.

## Local Use

The Jenkins pipeline configures the remote backend automatically. For manual local operations, use the same backend settings and Azure authentication, then run `terraform init -reconfigure` with the resource group, storage account, container (`tfstate`), and key (`aks-test.tfstate`) backend config values before `terraform plan`, `apply`, or `destroy`.

For a local-only test without remote state, temporarily remove the `backend "azurerm" {}` block from `versions.tf` and run:

```sh
terraform init
terraform validate
terraform apply
terraform destroy
```