# OpenShift Pipelines

- [Understanding OpenShift Pipelines](https://docs.openshift.com/container-platform/4.9/cicd/pipelines/understanding-openshift-pipelines.html)
- [Tekton overview](https://tekton.dev/docs/overview)
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

Install the Red Hat OpenShift Pipelines Operator based on Tekton from the OperatorHub
```sh
echo "Please Install the Red Hat OpenShift Pipelines Operator based on Tekton from the OperatorHub, go to :"
echo "$aro_console_url/operatorhub/ns/openshift-machine-api?category=Developer+Tools&keyword=Tekton"
```

## Create a dummy App. Pipeline

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

sa_secret_name=$(kubectl get serviceaccount pipeline -o json | jq -Mr '.secrets[].name')
echo "SA secret name " $sa_secret_name

# Openshift Cheatsheet: https://gist.github.com/rafaeltuelho/111850b0db31106a4d12a186e1fbc53e
sa_secret_value=$(oc get secrets  $sa_secret_name -o json | jq -Mr '.items[1].metadata.annotations["openshift.io/token-secret.value"]' | base64 -d)
echo "SA secret  " $sa_secret_value

kube_url=$(oc get endpoints -n default -o jsonpath='{.items[0].subsets[0].addresses[0].ip}')
echo "Kube URL " $kube_url

curl -k $aro_api_server_url/api/v1/namespaces -H "Authorization: Bearer $sa_secret_value" -H 'Accept: application/json'
curl -k $aro_api_server_url/apis/user.openshift.io/v1/users/~ -H "Authorization: Bearer $sa_secret_value" -H 'Accept: application/json'

oc adm policy add-scc-to-user privileged -z pipeline # system:serviceaccount:$projectname:pipeline
# oc policy add-role-to-user registry-editor -z pipeline

oc adm policy add-role-to-user edit -z pipeline
oc describe scc privileged

oc create -f ./cnf/apply_manifest_task.yaml
oc create -f ./cnf/update_deployment_task.yaml
oc create -f ./cnf/persistent_volume_claim.yaml
oc create -f ./cnf/storageclass-azurefile.yaml
oc apply -f  ./cnf/check-mvn-output-Task.yaml
oc apply -f  ./cnf/pipeline.yaml


oc apply -f ./cnf/maven_config_map.yaml
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


#TODO https://github.com/tektoncd/catalog/blob/main/task/buildah/0.3/samples/openshift-internal-registry.yaml

# Lets start a pipeline to build and deploy the petclinic admin-server backend application using tkn:
tkn pipeline start build-and-deploy \
    -w name=shared-workspace,volumeClaimTemplateFile=./cnf/persistent_volume_claim.yaml \
    -w name=maven-settings,config=maven-settings \
    -p deployment-name=admin-server \
    -p git-url=https://github.com/ezYakaEagle442/aro-java-petclinic-mic-srv \
    -p git-revision=master \
    -p DOCKERFILE=docker/petclinic-admin-server/Dockerfile \
    -p CONTEXT=. \
    -p IMAGE=image-registry.openshift-image-registry.svc:5000/$projectname/admin-server \
    -p FORMAT=oci \
    -p subdirectory=spring-petclinic-admin-server \
    -p manifest_dir=spring-petclinic-admin-server/k8s
    # --dry-run

# Debug/Troubleshoot:

oc describe task apply-manifests

oc describe task check-mvn-output
tkn task start check-mvn-output \
    -w name=output,volumeClaimTemplateFile=./cnf/persistent_volume_claim.yaml

#  get the route of the application by executing the following command and access the application
oc get route pipelines-admin-server --template='http://{{.spec.host}}'

# https://docs.openshift.com/container-platform/4.9/registry/accessing-the-registry.html
oc logs deployments/image-registry -n openshift-image-registry | grep -i "admin-server"


# Similarly, start a pipeline to build and deploy config-server application:

# Similarly, start a pipeline to build and deploy the UI client application:

# Similarly, start a pipeline to build and deploy customer service :

# Similarly, start a pipeline to build and deploy vets service :

# Similarly, start a pipeline to build and deploy visists service:


tkn pipeline list
tkn pipelinerun ls
tkn pipeline logs -f

# to re-run the pipeline again, use the following short-hand command to rerun the last pipelinerun again that uses the same workspaces, params and sa used in the previous pipeline run:
tkn pipeline start build-and-deploy --last


```
