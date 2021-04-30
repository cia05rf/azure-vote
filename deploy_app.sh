APP_NAME="azure-vote"
CONTAINER_REGISTRY="dockercontregrf"

func deploy \
     --platform kubernetes \
     --name $APP_NAME \
     --registry $CONTAINER_REGISTRY