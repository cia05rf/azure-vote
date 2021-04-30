RESOURCE_GROUP="MC_acdnd-c4-project_udacity-cluster_westus2"
APP_REGISTRY="appregrf"

az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $APP_REGISTRY \
    --node-count 1 \
    --enable-addons monitoring \
    --generate-ssh-keys