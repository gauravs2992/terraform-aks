variable "location" {
  description = "Azure region for the test resource group and cluster."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group created for this test cluster."
  type        = string
  default     = "rg-aks-test"
}

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
  default     = "aks-test-cluster"
}

variable "kubernetes_version" {
  description = "Optional Kubernetes version; null uses the Azure-supported default."
  type        = string
  default     = null
}

variable "node_count" {
  description = "Number of Linux nodes in the system node pool."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "node_vm_size" {
  description = "Azure VM size used by the system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "tags" {
  description = "Additional tags applied to the resource group and AKS cluster."
  type        = map(string)
  default     = {}
}