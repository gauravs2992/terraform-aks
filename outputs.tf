output "resource_group_name" {
  description = "Resource group containing the test AKS cluster."
  value       = azurerm_resource_group.aks.name
}

output "cluster_name" {
  description = "Name of the test AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}