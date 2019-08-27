#!/bin/bash
AFTER=$1
BEFORE=project_name

wget https://github.com/Mystery0Tools/BashScripts/raw/master/springboot/service-script/start-origin.sh
wget https://github.com/Mystery0Tools/BashScripts/raw/master/springboot/service-script/stop-origin.sh
wget https://github.com/Mystery0Tools/BashScripts/raw/master/springboot/service-script/update-origin.sh

sed "s/${BEFORE}/${AFTER}/g" start-origin.sh > start.sh
sed "s/${BEFORE}/${AFTER}/g" stop-origin.sh > stop.sh
sed "s/${BEFORE}/${AFTER}/g" update-origin.sh > update.sh

rm start-origin.sh
rm stop-origin.sh
rm update-origin.sh