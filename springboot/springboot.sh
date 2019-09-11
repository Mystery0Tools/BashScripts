#!/bin/bash
read -e -p " 请输入项目名称：" name
AFTER=$name
BEFORE=project_name

echo "正在创建目录……"
mkdir /var/"$AFTER"/
mkdir /var/"$AFTER"/config
mkdir /var/"$AFTER"/logs
cd /var/"$AFTER"/ || exit

echo "正在下载管理脚本……"
wget https://github.com/Mystery0Tools/BashScripts/raw/master/springboot/service-script/start-origin.sh
wget https://github.com/Mystery0Tools/BashScripts/raw/master/springboot/service-script/stop-origin.sh
wget https://github.com/Mystery0Tools/BashScripts/raw/master/springboot/service-script/update-origin.sh

echo "正在处理脚本……"
sed "s/${BEFORE}/${AFTER}/g" start-origin.sh > start.sh
sed "s/${BEFORE}/${AFTER}/g" stop-origin.sh > stop.sh
sed "s/${BEFORE}/${AFTER}/g" update-origin.sh > update.sh

rm start-origin.sh
rm stop-origin.sh
rm update-origin.sh

echo "操作完成！"