#!/bin/bash

PROJECT_NAME=$1

bash stop.sh "$PROJECT_NAME"
sleep 3
docker pull registry.cn-hangzhou.aliyuncs.com/mystery0/"$PROJECT_NAME":latest
docker rmi "$PROJECT_NAME"
docker tag registry.cn-hangzhou.aliyuncs.com/mystery0/"$PROJECT_NAME":latest "$PROJECT_NAME":latest
docker rmi registry.cn-hangzhou.aliyuncs.com/mystery0/"$PROJECT_NAME":latest
bash start.sh "$PROJECT_NAME"