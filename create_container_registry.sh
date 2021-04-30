RESOURCE_GROUP="MC_acdnd-c4-project_udacity-cluster_westus2"
CONTAINER_REGISTRY="dockercontregrf"

az acr create --resource-group $RESOURCE_GROUP --name $CONTAINER_REGISTRY --sku Basic