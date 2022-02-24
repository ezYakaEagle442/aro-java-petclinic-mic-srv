# ARO


```sh
appName="petcliaro"
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

# /!\ This query returns 3 Ids ....
aroRpObjectId="$(az ad sp list --filter "displayname eq 'Azure Red Hat OpenShift RP'" --query "[?appDisplayName=='Azure Red Hat OpenShift RP'].objectId" -o tsv | head -1)"

# The one below returns 1 & only 1 ID
tenantId=$(az account show --query tenantId -o tsv)
aroRpObjectId="$(az ad sp list --filter "displayname eq 'Azure Red Hat OpenShift RP'" --query "[?appDisplayName=='Azure Red Hat OpenShift RP']" --query "[?appOwnerTenantId=='$tenantId'].objectId" -o tsv | head -1)"

# /!\ The Role assignment must be run manually for each of the 3 RP SP
az ad sp list --filter "displayname eq 'Azure Red Hat OpenShift RP'" --query "[?appDisplayName=='Azure Red Hat OpenShift RP'].objectId" -o tsv |
while IFS= read -r line
do
    echo "$line" &
done

# az account list-locations : swedencentral | francecentral | northeurope | westeurope | eastus2
location="northeurope" 

az group create --name rg-iac-kv --location $location
az group create --name rg-iac-aro-petclinic-mic-srv --location $location

az deployment group create --name iac-101-kv -f iac/bicep/kv/kv.bicep -g rg-iac-kv \
    --parameters @iac/bicep/kv/parameters-kv.json

# /!\ ARO RP Object ID : there is a correlation issue between Portal & CLI
# https://github.com/Azure/terraform-azurerm-appgw-ingress-k8s-cluster/issues/1
# When you create a new "app registration" in the Azure portal, actually two objects are created: 
# An application object and a service principal object. The object ID which appears in the Azure portal is the
# application object ID, not the service principal object ID.

# /!\ In ./aro/parameters.json; envsubst will replace the here uner parameters with your values :
# clientId, clientObjectId, clientSecret, aroRpObjectId, pullSecret
export clientId=$aro_sp_id
export clientObjectId=$clientObjectId
export clientSecret=$aro_sp_password
export aroRpObjectId=$aroRpObjectId


# /!\ Bicep will complain about the pullSecret as it has quotes “ and curly brackets which need to be escaped …
cat pull-secret.txt | sed 's/"/\\"/g' > pull-secret-escaped.txt
export pullSecret=`cat pull-secret-escaped.txt`

envsubst < iac/bicep/aro/parameters.json > ../parameters-aro.json
cat ../parameters-aro.json


az deployment group create --name iac-101-aro -f iac/bicep/aro/main.bicep -g rg-iac-aro-petclinic-mic-srv \
    --parameters @../parameters-aro.json
    
```
## Connect to the Cluster

See [https://docs.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster#connect-to-the-cluster](https://docs.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster#connect-to-the-cluster)

```sh
aro_rg_name="rg-iac-aro-petclinic-mic-srv"
aro_cluster_name="aro-java-petclinic"

az aro list-credentials -n $aro_cluster_name -g $aro_rg_name
aro_usr=$(az aro list-credentials -n $aro_cluster_name -g $aro_rg_name | jq -r '.kubeadminUsername')
aro_pwd=$(az aro list-credentials -n $aro_cluster_name -g $aro_rg_name | jq -r '.kubeadminPassword')

# Launch the console URL in a browser and login using the kubeadmin credentials.
aro_console_url=$(az aro show -n $aro_cluster_name -g $aro_rg_name --query 'consoleProfile.url' -o tsv)
echo "ARO console URL: " $aro_console_url

aro_api_server_url=$(az aro show -n $aro_cluster_name -g $aro_rg_name --query 'apiserverProfile.url' -o tsv)
echo "ARO API server URL: " $aro_api_server_url

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
