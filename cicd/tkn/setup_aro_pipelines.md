# OpenShift Pipelines

- [Understanding OpenShift Pipelines](https://docs.openshift.com/container-platform/4.9/cicd/pipelines/understanding-openshift-pipelines.html)
- [Tekton overview](https://tekton.dev/docs/overview)
- [How to use Tekton to set up a CI pipeline with OpenShift Pipelines](https://www.redhat.com/architect/cicd-pipeline-openshift-tekton)
- [TektonCD Pipelines](https://github.com/tektoncd/pipeline/blob/master/docs/pipelines.md)
- [Guide to OpenShift pipelines part 2](https://www.openshift.com/blog/guide-to-openshift-pipelines-part-2-using-source-2-image-build-in-tekton)
- [Guide to OpenShift pipelines part4](https://www.openshift.com/blog/guide-to-openshift-pipelines-part-4-application-deployment-and-pipeline-orchestration-1)
- [https://vincent.demeester.fr/articles/tekton-pipeline-without-pipeline-resources.html](https://vincent.demeester.fr/articles/tekton-pipeline-without-pipeline-resources.html)
- [https://github.com/tektoncd/pipeline/tree/release-v0.22.x/examples/v1beta1](https://github.com/tektoncd/pipeline/tree/release-v0.22.x/examples/v1beta1)

## pre-req
Check tkn cli is installed

## How to install Tekton CLI
[https://github.com/tektoncd/cli](https://github.com/tektoncd/cli)

### From Linux AMD64 / WSL
```sh
tkn_version=0.22.0
# Get the tar.xz
curl -LO https://github.com/tektoncd/cli/releases/download/v$tkn_version/tkn_$tkn_version\_Linux_x86_64.tar.gz
# Extract tkn to your PATH (e.g. /usr/local/bin)
sudo tar xvzf tkn_$tkn_version\_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn
```
### Mac
```sh
brew install tektoncd-cli
```
### From Chocolatey
```sh
choco install tektoncd-cli --confirm
```

```sh
source <(tkn completion bash)
complete -F __start_tkn tkn

tkn help
tkn version
```
## get ARO credentials

```sh
# those var name are set in the Bicep parameter files , check them at /iac/bicep/README.md & /iac/bicep/aro/parameters.json
rg_name="rg-iac-aro-petclinic-mic-srv" 
cluster_name="aro-java-petclinic"

aro_api_server_url=$(az aro show -n $cluster_name -g $rg_name --query 'apiserverProfile.url' -o tsv)
echo "ARO API server URL: " $aro_api_server_url

aro_console_url=$(az aro show -n $cluster_name -g $rg_name --query 'consoleProfile.url' -o tsv)
echo "ARO console URL: " $aro_console_url

az aro list-credentials -n $cluster_name -g $rg_name
aro_usr=$(az aro list-credentials -n $cluster_name -g $rg_name | jq -r '.kubeadminUsername')
aro_pwd=$(az aro list-credentials -n $cluster_name -g $rg_name | jq -r '.kubeadminPassword')

```

## Install the OpenShift CLI

See [https://docs.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster#install-the-openshift-cli](https://docs.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster#install-the-openshift-cli)
```sh
cd ~
aro_download_url=${aro_console_url/console/downloads}
echo "aro_download_url" $aro_download_url

wget $aro_download_url/amd64/linux/oc.tar

mkdir openshift
tar -xvf oc.tar -C openshift
echo 'export PATH=$PATH:~/openshift' >> ~/.bashrc && source ~/.bashrc
oc version

source <(oc completion bash)
echo "source <(oc completion bash)" >> ~/.bashrc 

oc login $aro_api_server_url -u $aro_usr -p $aro_pwd
oc whoami
oc cluster-info

```

Install the Red Hat OpenShift Pipelines Operator based on Tekton from the OperatorHub
```sh
echo "Please Install the Red Hat OpenShift Pipelines Operator based on Tekton from the OperatorHub, go to :"
echo "$aro_console_url/operatorhub/ns/openshift-machine-api?category=Developer+Tools&keyword=Tekton"
```

## Create the Pipeline

```sh
projectname="petclinic"
oc new-project $projectname

oc config current-context
oc status
oc projects
oc project $projectname

oc create serviceaccount pipeline
oc get sa pipeline
oc describe sa pipeline

sa_secret_name=$(oc get serviceaccount pipeline -o json | jq -Mr '.secrets[].name')
echo "SA secret name " $sa_secret_name

# Openshift Cheatsheet: https://gist.github.com/rafaeltuelho/111850b0db31106a4d12a186e1fbc53e
sa_secret_value=$(oc get secrets  $sa_secret_name -o json | jq -Mr '.items[0].metadata.annotations["openshift.io/token-secret.value"]') # | base64 -d)
echo "SA secret  " $sa_secret_value

kube_url=$(oc get endpoints -n default -o jsonpath='{.items[0].subsets[0].addresses[0].ip}')
echo "Kube URL " $kube_url

curl -k $aro_api_server_url/api/v1/namespaces -H "Authorization: Bearer $sa_secret_value" -H 'Accept: application/json'
curl -k $aro_api_server_url/apis/user.openshift.io/v1/users/~ -H "Authorization: Bearer $sa_secret_value" -H 'Accept: application/json'

oc adm policy add-scc-to-user privileged -z pipeline # system:serviceaccount:$projectname:pipeline

oc adm policy add-role-to-user edit -z pipeline
oc describe scc privileged

oc create -f cicd/tkn/cnf/storageclass-azurefile.yaml
oc create -f cicd/tkn/cnf/persistent_volume_claim.yaml
oc create -f cicd/tkn/cnf/get_image_tags_task.yaml
oc create -f cicd/tkn/cnf/apply_manifest_task.yaml
oc create -f cicd/tkn/cnf/update_deployment_task.yaml
oc apply -f  cicd/tkn/cnf/check-mvn-output-Task.yaml
oc apply -f  cicd/tkn/cnf/pipeline.yaml

oc apply -f cicd/tkn/cnf/maven_config_map.yaml
oc describe cm maven-settings
oc get cm maven-settings -o jsonpath='{.data.settings\.xml}'

tkn task ls
tkn clustertask ls
tkn pipeline list
tkn pr list # pipelineruns
tkn tr list # taskruns

oc get tektonconfigs
oc describe tektonconfig config
oc describe clustertask git-clone-1-5-0
oc describe clustertask buildah
oc describe clustertask maven

```
## Run the Pipeline
```sh
#TODO https://github.com/tektoncd/catalog/blob/main/task/buildah/0.3/samples/openshift-internal-registry.yaml

location=$(az aro show -n $cluster_name -g $rg_name --query 'location' -o tsv)
domain=$(az aro show -n $cluster_name -g $rg_name --query 'clusterProfile.domain' -o tsv)
namespace=$projectname

# /!\ ING_HOST in the Ingress yaml files must match with the default route set at 
# spring-petclinic-api-gateway/k8s/petclinic-ui-route.yaml
ING_HOST="ui-$namespace.apps.$domain.$location.aroapp.io"

tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=cicd/tkn/cnf/persistent_volume_claim.yaml \
    -w name=maven-settings,config=maven-settings \
    -p deployment-name=config-server \
    -p git-url=https://github.com/ezYakaEagle442/aro-java-petclinic-mic-srv \
    -p git-revision=master \
    -p DOCKERFILE=docker/petclinic-config-server/Dockerfile \
    -p CONTEXT=. \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$projectname/petclinic-config-server \
    -p FORMAT=oci \
    -p subdirectory=spring-petclinic-config-server \
    -p manifest_dir=spring-petclinic-config-server/k8s \
    -p ING_HOST=$ING_HOST

###############################################################################################
#
# WAIT FOR CONFIG-SERVER Pods (3) TO BE Up & Running in READY STATE ...
#
###############################################################################################
tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=cicd/tkn/cnf/persistent_volume_claim.yaml \
    -w name=maven-settings,config=maven-settings \
    -p deployment-name=admin-server \
    -p git-url=https://github.com/ezYakaEagle442/aro-java-petclinic-mic-srv \
    -p git-revision=master \
    -p DOCKERFILE=docker/petclinic-admin-server/Dockerfile \
    -p CONTEXT=. \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$projectname/admin-server \
    -p FORMAT=oci \
    -p subdirectory=spring-petclinic-admin-server \
    -p manifest_dir=spring-petclinic-admin-server/k8s \
    -p ING_HOST=$ING_HOST
    # --dry-run

tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=cicd/tkn/cnf/persistent_volume_claim.yaml \
    -w name=maven-settings,config=maven-settings \
    -p deployment-name=vets-service \
    -p git-url=https://github.com/ezYakaEagle442/aro-java-petclinic-mic-srv \
    -p git-revision=master \
    -p DOCKERFILE=docker/petclinic-vets-service/Dockerfile \
    -p CONTEXT=. \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$projectname/petclinic-vets-service \
    -p FORMAT=oci \
    -p subdirectory=spring-petclinic-vets-service \
    -p manifest_dir=spring-petclinic-vets-service/k8s \
    -p ING_HOST=$ING_HOST

tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=cicd/tkn/cnf/persistent_volume_claim.yaml \
    -w name=maven-settings,config=maven-settings \
    -p deployment-name=visits-service \
    -p git-url=https://github.com/ezYakaEagle442/aro-java-petclinic-mic-srv \
    -p git-revision=master \
    -p DOCKERFILE=docker/petclinic-visits-service/Dockerfile \
    -p CONTEXT=. \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$projectname/petclinic-visits-service \
    -p FORMAT=oci \
    -p subdirectory=spring-petclinic-visits-service \
    -p manifest_dir=spring-petclinic-visits-service/k8s \
    -p ING_HOST=$ING_HOST

tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=cicd/tkn/cnf/persistent_volume_claim.yaml \
    -w name=maven-settings,config=maven-settings \
    -p deployment-name=customers-service \
    -p git-url=https://github.com/ezYakaEagle442/aro-java-petclinic-mic-srv \
    -p git-revision=master \
    -p DOCKERFILE=docker/petclinic-customers-service/Dockerfile \
    -p CONTEXT=. \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$projectname/petclinic-customers-service \
    -p FORMAT=oci \
    -p subdirectory=spring-petclinic-customers-service \
    -p manifest_dir=spring-petclinic-customers-service/k8s \
    -p ING_HOST=$ING_HOST

tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=cicd/tkn/cnf/persistent_volume_claim.yaml \
    -w name=maven-settings,config=maven-settings \
    -p deployment-name=ui-service \
    -p git-url=https://github.com/ezYakaEagle442/aro-java-petclinic-mic-srv \
    -p git-revision=master \
    -p DOCKERFILE=docker/petclinic-api-gateway/Dockerfile \
    -p CONTEXT=. \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$projectname/petclinic-ui \
    -p FORMAT=oci \
    -p subdirectory=spring-petclinic-api-gateway \
    -p manifest_dir=spring-petclinic-api-gateway/k8s \
    -p ING_HOST=$ING_HOST

#  get the route of the application by executing the following command and access the application
oc get route ui --template='http://{{.spec.host}}'

# Debug/Troubleshoot:

oc describe task apply-manifests

oc describe task check-mvn-output
tkn task start check-mvn-output \
    -w name=output,volumeClaimTemplateFile=cicd/tkn/cnf/persistent_volume_claim.yaml

# https://docs.openshift.com/container-platform/4.9/registry/accessing-the-registry.html
oc logs deployments/image-registry -n openshift-image-registry | grep -i "customers-service"

tkn pipeline list
tkn pipelinerun ls
tkn pipeline logs -f

# to re-run the pipeline again, use the following short-hand command to rerun the last pipelinerun again that uses the same workspaces, params and sa used in the previous pipeline run:
tkn pipeline start build-and-deploy --last
```
