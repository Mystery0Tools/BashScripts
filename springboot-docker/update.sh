#!/bin/bash
PROJECT_NAME=$(cat config | grep "project=" | awk -F "=" '{print $NF}')

docker stop $PROJECT_NAME
sleep 3
docker pull registry.cn-hangzhou.aliyuncs.com/mystery0/$PROJECT_NAME:latest
docker rmi $PROJECT_NAME
docker tag registry.cn-hangzhou.aliyuncs.com/mystery0/$PROJECT_NAME:latest $PROJECT_NAME:latest
docker rmi registry.cn-hangzhou.aliyuncs.com/mystery0/$PROJECT_NAME:latest
bash start.sh