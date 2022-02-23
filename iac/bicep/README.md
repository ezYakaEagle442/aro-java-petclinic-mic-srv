# ARO


```sh
aro_sp_password=$(az ad sp create-for-rbac --name $appName-aro --role contributor --query password -o tsv)
echo $aro_sp_password > aro_spp.txt
echo "Service Principal Password saved to ./aro_spp.txt IMPORTANT Keep your password ..." 
# aro_sp_password=`cat aro_spp.txt`
#aro_sp_id=$(az ad sp show --id http://$appName-aro --query appId -o tsv) # | jq -r .appId
#aro_sp_id=$(az ad sp list --all --query "[?appDisplayName=='${appName}-aro'].{appId:appId}" --output tsv)
aro_sp_id=$(az ad sp list --show-mine --query "[?appDisplayName=='${appName}-aro'].{appId:appId}" -o tsv)
echo "Service Principal ID:" $aro_sp_id 
echo $aro_sp_id > aro_spid.txt
# aro_sp_id=`cat aro_spid.txt`
az ad sp show --id $aro_sp_id

clientObjectId="$(az ad sp list --filter "AppId eq '$aro_sp_id'" --query "[?appId=='$aro_sp_id'].objectId" -o tsv)"

aroRpObjectId="$(az ad sp list --filter "displayname eq 'Azure Red Hat OpenShift RP'" --query "[?appDisplayName=='Azure Red Hat OpenShift RP'].objectId" -o tsv)"

pull_secret=`cat pull-secret.txt`

# az account list-locations : swedencentral | francecentral | northeurope | westeurope | eastus2
location="swedencentral" 

az group create --name rg-iac-kv --location $location
az group create --name rg-iac-aro-petclinic-mic-srv --location $location

az deployment group create --name iac-101-kv -f ./kv/kv.bicep -g rg-iac-kv \
    --parameters @./kv/parameters-kv.json

# /!\ In ./aro/parameters.json; replace the here uner parameters with your values :
# clientObjectId, clientSecret, aroRpObjectId, pullSecret, domain

envsubst < $(inputs.params.manifest_dir)/$i > $(inputs.params.manifest_dir)/deploy/$i

az deployment group create --name iac-101-aro -f ./aro/main.bicep -g rg-iac-aro-petclinic-mic-srv \
    --parameters @./aro/parameters.json
    
az deployment group create --name iac-101-aro \
    -f ./aro/main.bicep \
    -g $aro_rg_name \
    --parameters clientId=$aro_sp_id \
        clientObjectId=$clientObjectId \
        clientSecret=$aro_sp_password \
        aroRpObjectId=$aroRpObjectId \
        pullSecret=$pull_secret \
        domain=openshiftrocks
```
## Connect to the Cluster

See [https://docs.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster#connect-to-the-cluster](https://docs.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster#connect-to-the-cluster)

```sh
az aro list-credentials -n $aro_cluster_name -g $aro_rg_name
aro_usr=$(az aro list-credentials -n $aro_cluster_name -g $aro_rg_name | jq -r '.kubeadminUsername')
aro_pwd=$(az aro list-credentials -n $aro_cluster_name -g $aro_rg_name | jq -r '.kubeadminPassword')

# Launch the console URL in a browser and login using the kubeadmin credentials.

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
oc config current-context
oc describe ingresscontroller default -n openshift-ingress-operator

```


## Create Namespaces
```sh

oc config view --minify | grep namespace

oc create namespace development
oc label namespace/development purpose=development

oc create namespace staging
oc label namespace/staging purpose=staging

oc create namespace production
oc label namespace/production purpose=production

oc create namespace sre
oc label namespace/sre purpose=sre

oc get ns --show-labels
oc describe namespace production
```
