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

            terraform init -input=false
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
            terraform init -input=false
            terraform destroy -input=false -auto-approve
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
              terraform init -input=false
              terraform destroy -input=false -auto-approve
            ''')
            if (destroyStatus != 0) {
              currentBuild.result = 'FAILURE'
              echo 'AKS cleanup failed. Check the Terraform destroy output and remove any remaining Azure resources.'
            }
          }
        }
      }
    }
  }
}