#!/bin/bash

PROJECT_NAME=project_name

docker run --rm -it -d --name "$PROJECT_NAME" -v /var/"$PROJECT_NAME"/config:/config -v /var/"$PROJECT_NAME"/logs:/logs "$PROJECT_NAME"