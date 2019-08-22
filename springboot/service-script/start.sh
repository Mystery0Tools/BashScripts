#!/bin/bash

PROJECT_NAME=project_name

docker run --rm -it -d --name "$PROJECT_NAME" --net=host -v /var/log/springboot/"$PROJECT_NAME"/config:/config -v /var/log/springboot/"$PROJECT_NAME"/logs:/logs "$PROJECT_NAME"