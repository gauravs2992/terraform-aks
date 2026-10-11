pipeline {
  agent any

  options {
    disableConcurrentBuilds()
    timestamps()
  }

  parameters {
    choice(
      name: 'ACTION',
      choices: ['CREATE_AND_DESTROY', 'CREATE', 'DESTROY'],
      description: 'Default runs a full ephemeral AKS test. CREATE and DESTROY support separate runs.'
    )
    string(
      name: 'STATE_STORAGE_ACCOUNT',
      defaultValue: '',
      description: 'Globally unique lowercase Azure Storage account name (3-24 characters). Required.'
    )
    string(
      name: 'STATE_RESOURCE_GROUP',
      defaultValue: 'rg-aks-terraform-state',
      description: 'Dedicated resource group for the Terraform state storage. It is deleted after DESTROY.'
    )
  }

  environment {
    TF_IN_AUTOMATION = 'true'
    TF_INPUT         = 'false'
    AZURE_CONFIG_DIR = "${WORKSPACE}/.azure"
  }

  stages {
    stage('Provision AKS') {
      when {
        expression { params.ACTION != 'DESTROY' }
      }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'azure-service-principal', usernameVariable: 'ARM_CLIENT_ID', passwordVariable: 'ARM_CLIENT_SECRET'),
          string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
          string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID')
        ]) {
          sh '''
            set -eu
            az login --service-principal \
              --username "$ARM_CLIENT_ID" \
              --password "$ARM_CLIENT_SECRET" \
              --tenant "$ARM_TENANT_ID" \
              --output none
            az account set --subscription "$ARM_SUBSCRIPTION_ID"

            test -n "$STATE_STORAGE_ACCOUNT"
            if ! printf '%s' "$STATE_STORAGE_ACCOUNT" | grep -Eq '^[a-z0-9]{3,24}$'; then
              echo 'STATE_STORAGE_ACCOUNT must be 3-24 lowercase letters or numbers.' >&2
              exit 1
            fi

            az group create --name "$STATE_RESOURCE_GROUP" --location eastus --output none
            az storage account create \
              --name "$STATE_STORAGE_ACCOUNT" \
              --resource-group "$STATE_RESOURCE_GROUP" \
              --location eastus \
              --sku Standard_LRS \
              --kind StorageV2 \
              --https-only true \
              --min-tls-version TLS1_2 \
              --allow-blob-public-access false \
              --output none

            set +x
            export ARM_ACCESS_KEY="$(az storage account keys list \
              --resource-group "$STATE_RESOURCE_GROUP" \
              --account-name "$STATE_STORAGE_ACCOUNT" \
              --query '[0].value' --output tsv)"
            az storage container create \
              --name tfstate \
              --account-name "$STATE_STORAGE_ACCOUNT" \
              --account-key "$ARM_ACCESS_KEY" \
              --output none

            terraform init -input=false -reconfigure \
              -backend-config="resource_group_name=$STATE_RESOURCE_GROUP" \
              -backend-config="storage_account_name=$STATE_STORAGE_ACCOUNT" \
              -backend-config="container_name=tfstate" \
              -backend-config="key=aks-test.tfstate"
            terraform fmt -check -recursive
            terraform validate
            terraform plan -input=false -out=tfplan
            terraform apply -input=false -auto-approve tfplan
          '''
        }
      }
    }

    stage('Verify AKS') {
      when {
        expression { params.ACTION != 'DESTROY' }
      }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'azure-service-principal', usernameVariable: 'ARM_CLIENT_ID', passwordVariable: 'ARM_CLIENT_SECRET'),
          string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
          string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID')
        ]) {
          sh '''
            set -eu
            az login --service-principal \
              --username "$ARM_CLIENT_ID" \
              --password "$ARM_CLIENT_SECRET" \
              --tenant "$ARM_TENANT_ID" \
              --output none
            az account set --subscription "$ARM_SUBSCRIPTION_ID"

            set +x
            export ARM_ACCESS_KEY="$(az storage account keys list \
              --resource-group "$STATE_RESOURCE_GROUP" \
              --account-name "$STATE_STORAGE_ACCOUNT" \
              --query '[0].value' --output tsv)"
            terraform init -input=false -reconfigure \
              -backend-config="resource_group_name=$STATE_RESOURCE_GROUP" \
              -backend-config="storage_account_name=$STATE_STORAGE_ACCOUNT" \
              -backend-config='container_name=tfstate' \
              -backend-config='key=aks-test.tfstate'
            export KUBECONFIG="$WORKSPACE/.kubeconfig"
            az aks get-credentials \
              --resource-group "$(terraform output -raw resource_group_name)" \
              --name "$(terraform output -raw cluster_name)" \
              --overwrite-existing
            kubectl wait --for=condition=Ready nodes --all --timeout=5m
            kubectl get nodes
          '''
        }
      }
    }

    stage('Destroy AKS') {
      when {
        expression { params.ACTION == 'DESTROY' }
      }
      steps {
        withCredentials([
          usernamePassword(credentialsId: 'azure-service-principal', usernameVariable: 'ARM_CLIENT_ID', passwordVariable: 'ARM_CLIENT_SECRET'),
          string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
          string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID')
        ]) {
          sh '''
            set -eu
            az login --service-principal \
              --username "$ARM_CLIENT_ID" \
              --password "$ARM_CLIENT_SECRET" \
              --tenant "$ARM_TENANT_ID" \
              --output none
            az account set --subscription "$ARM_SUBSCRIPTION_ID"
            set +x
            export ARM_ACCESS_KEY="$(az storage account keys list \
              --resource-group "$STATE_RESOURCE_GROUP" \
              --account-name "$STATE_STORAGE_ACCOUNT" \
              --query '[0].value' --output tsv)"
            terraform init -input=false -reconfigure \
              -backend-config="resource_group_name=$STATE_RESOURCE_GROUP" \
              -backend-config="storage_account_name=$STATE_STORAGE_ACCOUNT" \
              -backend-config='container_name=tfstate' \
              -backend-config='key=aks-test.tfstate'
            terraform destroy -input=false -auto-approve
            az group delete --name "$STATE_RESOURCE_GROUP" --yes
          '''
        }
      }
    }
  }

  post {
    always {
      script {
        if (params.ACTION == 'CREATE_AND_DESTROY') {
          withCredentials([
            usernamePassword(credentialsId: 'azure-service-principal', usernameVariable: 'ARM_CLIENT_ID', passwordVariable: 'ARM_CLIENT_SECRET'),
            string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
            string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID')
          ]) {
            def destroyStatus = sh(returnStatus: true, script: '''
              set -eu
              az login --service-principal \
                --username "$ARM_CLIENT_ID" \
                --password "$ARM_CLIENT_SECRET" \
                --tenant "$ARM_TENANT_ID" \
                --output none
              az account set --subscription "$ARM_SUBSCRIPTION_ID"
              set +x
              export ARM_ACCESS_KEY="$(az storage account keys list \
                --resource-group "$STATE_RESOURCE_GROUP" \
                --account-name "$STATE_STORAGE_ACCOUNT" \
                --query '[0].value' --output tsv)"
              terraform init -input=false -reconfigure \
                -backend-config="resource_group_name=$STATE_RESOURCE_GROUP" \
                -backend-config="storage_account_name=$STATE_STORAGE_ACCOUNT" \
                -backend-config='container_name=tfstate' \
                -backend-config='key=aks-test.tfstate'
              terraform destroy -input=false -auto-approve
            ''')
            if (destroyStatus == 0) {
              def storageCleanupStatus = sh(returnStatus: true, script: '''
                az group delete --name "$STATE_RESOURCE_GROUP" --yes
              ''')
              if (storageCleanupStatus != 0) {
                currentBuild.result = 'FAILURE'
                echo 'AKS was destroyed, but the Terraform state storage resource group could not be deleted.'
              }
            } else {
              currentBuild.result = 'FAILURE'
              echo 'AKS destroy failed. Terraform state storage was retained for recovery.'
            }
          }
        }
      }
    }
  }
}