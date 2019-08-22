#!/bin/bash

PROJECT_NAME=$(cat config | grep "project=" | awk -F "=" '{print $NF}')

docker run --rm -it -d --name $PROJECT_NAME --net=host -v ~/$PROJECT_NAME/config:/config -v ~/$PROJECT_NAME/logs:/logs $PROJECT_NAME