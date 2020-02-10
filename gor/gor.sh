#!/bin/bash
sh_ver='1.0.2'
gor='/usr/local/bin/gor'
gor_config='/etc/gor/gor.config'
gor_config_template='gor.config.template'
gor_capture_log='capture.log'
gor_reply_log='reply.log'
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Yellow_font_prefix="\033[33m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Yellow_background_prefix="\033[43;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"

check_root() {
  [[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

check_system() {
  if [[ "$(uname)" == "Darwin" ]]; then
    system='mac'
    # Mac OS X 操作系统
    echo -e "${Info} 检测到 Mac OS X 操作系统"
    echo -e "${Error} 因为能力原因，Mac 上暂时无法使用回放流量功能"
  elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
    system='linux'
    # GNU/Linux操作系统
    echo -e "${Info} 检测到 GNU/Linux操作系统"
  elif [[ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]]; then
    system='windows'
    # Windows NT操作系统
    echo -e "${Info} 检测到 Windows NT操作系统"
    echo -e "${Error} 该脚本暂时无法在 Windows 上使用"
    if [[ $1 == "force_enable_on_windows" ]]; then
      echo -e "${Tip} 已启用强制运行模式，可能再执行某些操作时出现问题"
    else
      exit 1
    fi
  fi
}

check_dir() {
  if [[ ! -e '/var/log/gor' ]]; then
    mkdir '/var/log/gor'
  fi
  if [[ ! -e '/etc/gor' ]]; then
    mkdir '/etc/gor'
  fi
  if [[ ! -e "$gor_config" ]]; then
    [[ ! -e ${gor_config_template} ]] && echo -e "${Error} 配置模板文件不存在，请检查 !" && exit 1
    cp "$gor_config_template" "$gor_config"
  fi
}

check_installed_status() {
  if [[ ! -e ${gor} ]]; then
    # 判断当前目录是否存在可执行文件
    case $system in
    'mac')
      if [[ ! -e 'gor_mac' ]]; then
        echo -e "${Error} gor 没有安装，请检查 !" && exit 1
      else
        # 当前目录存在，拷贝到 /usr/local/bin 去
        cp -rf 'gor_mac' "$gor"
        return 0
      fi
      ;;
    'linux')
      if [[ ! -e 'gor_x64' ]]; then
        echo -e "${Error} gor 没有安装，请检查 !" && exit 1
      else
        # 当前目录存在，拷贝到 /usr/local/bin 去
        cp -rf 'gor_x64' "$gor"
        return 0
      fi
      ;;
    esac
    echo -e "${Error} gor 没有安装，请检查 !" && exit 1
  fi
}

check_pid() {
  PID=$(ps -ef | grep "$gor" | grep -v grep | awk '{print $2}')
}

config() {
  source "$gor_config"
}

show_status() {
  if [[ -e ${gor} ]]; then
    check="true"
  else
    check="false"
  fi
  if [[ ${check} == "true" ]]; then
    check_pid
    if [[ -n "${PID}" ]]; then
      echo -e "当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
    else
      echo -e "当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
    fi
  else
    echo -e "当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
  fi
}

do_config() {
  key=$1
  value=$2
  sed "s~$key=.*~$key=$value~g" <"$gor_config" >"temp"
  mv "temp" "$gor_config"
  rm -rf "temp"
  config
}

capture_traffic() {
  config
  check_installed_status
  check_pid
  if [[ ! -e ${config_save_dir} ]]; then
    mkdir "$config_save_dir"
  fi
  if [[ -n "${PID}" ]]; then
    echo -e "${Tip} gor 已经启动，是否需要重新启动?  (y/N)"
    read -e -p "(默认: n):" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
      kill -9 "${PID}"
    else
      echo "重新启动已取消..." && exit 1
    fi
  fi
  echo && echo -e " 请输入监听的端口 [1-65535]（端口信息将会保存起来）" && echo
  read -e -p "(默认: $config_listen_port):" listen_port
  [[ -z ${listen_port} ]] && listen_port=$config_listen_port
  if [[ "$listen_port" != "$config_listen_port" ]]; then
    do_config 'config_listen_port' $listen_port
  fi
  "$gor" \
    --input-raw :"$listen_port" \
    --output-file="$config_save_dir/$config_file_format" \
    --output-file-queue-limit 0 \
    --output-file-size-limit "$config_file_size_limit" >"$config_log/$gor_capture_log" 2>&1 &
  echo -e "${Info} gor 启动成功！"
}

stop_capture_traffic() {
  config
  check_installed_status
  check_pid
  [[ -z ${PID} ]] && echo -e "${Error} gor 没有运行，请检查 !" && exit 1
  kill -9 "${PID}"
  echo -e "${Info} gor 停止成功！"
}

parse_time() {
  year=$(echo "$1" | cut -d- -f1)
  [[ -z $year || ! "$config_file_format" =~ %Y ]] && year=1900
  month=$(echo "$1" | cut -d- -f2)
  [[ -z $month || ! "$config_file_format" =~ %m ]] && month=01
  day=$(echo "$1" | cut -d- -f3)
  [[ -z $day || ! "$config_file_format" =~ %d ]] && day=01
  hour=$(echo "$1" | cut -d- -f4)
  [[ -z $hour || ! "$config_file_format" =~ %H ]] && hour=00
  minute=$(echo "$1" | cut -d- -f5)
  [[ -z $minute || ! "$config_file_format" =~ %M ]] && minute=00
  second=$(echo "$1" | cut -d- -f6)
  [[ -z $second || ! "$config_file_format" =~ %S ]] && second=00
  echo "$year/$month/$day $hour:$minute:$second"
}

replay_traffic_while() {
  log_file=$1
  file_string=$(ls -rt "$config_save_dir" | tr "\n" " ")
  files=($file_string)
  length=${#files[*]}
  index=0
  tmp_dir='temp_dir_do_not_delete'
  mkdir "$tmp_dir"
  while [[ $index -lt $length ]]; do
    gor_file=${files[$index]}
    file_name=$(echo "$gor_file" | cut -d_ -f1)
    date=$(parse_time "$file_name")
    temp_time=$(date -d "$date" +"%s")
    if [[ "$disable_time_split" == "true" || ($temp_time -ge $start_time && $temp_time -le $end_time) ]]; then
      cp "$config_save_dir/$gor_file" "$tmp_dir"
    fi
    ((index++))
  done
  ("$gor" \
        --input-file "$tmp_dir/*|$config_replay_speed" \
        --output-http "$config_output_http" \
        --http-allow-method GET \
        --http-allow-method POST \
        --http-allow-method PUT \
        --http-allow-method DELETE \
        --http-allow-method PATCH  && rm -rf $tmp_dir) > "$log_file" 2>&1 &
}

replay_traffic() {
  config
  check_pid
  if [[ -n "${PID}" ]]; then
    echo -e "${Tip} gor 正在运行中，需要先停止当前的运行实例吗?  (y/N)"
    read -e -p "(默认: n):" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
      kill -9 "${PID}"
    else
      echo "已取消..." && exit 1
    fi
  fi
  disable_time_split=false
  start_time=''
  end_time=''
  replay_speed=''
  echo && echo -e "格式：yyyy/MM/dd hh:mm:ss"
  echo -e " 请输入回放的开始时间：" && echo
  while [[ "$disable_time_split" == "false" && -z "$start_time" ]]; do
    read -e -p "(回车：不启用)" input_start_time
    [[ -z ${input_start_time} ]] && disable_time_split=true
    if [[ "$disable_time_split" == "false" ]]; then
      if [[ $input_start_time =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}\ [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$ ]]; then
        start_time=$(date -d "$input_start_time" +"%s")
        if [[ $? != 0 ]]; then
          echo -e "${Error} 格式不正确，请重新输入！"
          start_time=''
        fi
      else
        echo -e "${Error} 格式不正确，请重新输入！"
        start_time=''
      fi
    fi
  done
  if [[ "$disable_time_split" == "false" ]]; then
    echo -e " 请输入回放的结束时间："
  fi
  while [[ "$disable_time_split" == "false" && -z "$end_time" ]]; do
    read -e -p "(回车：当前时间)" input_end_time
    [[ -z ${input_end_time} ]] && input_end_time=$(date +"%Y/%m/%d %H:%M:%S")
    if [[ $input_end_time =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}\ [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$ ]]; then
      end_time=$(date -d "$input_end_time" +"%s")
      if [[ $? != 0 ]]; then
        echo -e "${Error} 格式不正确，请重新输入！"
        end_time=''
      fi
    else
      echo -e "${Error} 格式不正确，请重新输入！"
      end_time=''
    fi
  done
  echo && echo -e " 请输入回放流量时的速度(直接输入百分数，仅支持百分数)" && echo
  while [[ -z $replay_speed ]]; do
    read -e -p "(默认:$config_replay_speed):" replay_speed
    [[ -z "${replay_speed}" ]] && replay_speed=$config_replay_speed
    if [[ $replay_speed =~ ^[0-9]+%$ && ${replay_speed%?} -gt 0 ]]; then
      do_config 'config_replay_speed' "$replay_speed"
    else
      echo -e "${Error} 格式不正确！"
      replay_speed=''
    fi
  done

  echo -e "${Info} 当前输出的http url【${Green_font_prefix}$config_output_http${Font_color_suffix}】"
  echo -e "${Tip} 如果需要更改，请取消本次操作后通过脚本进行修改"
  echo && echo -e " 确认运行？(Y/n)" && echo
  read -e -p "(默认: 确认):" unyn
  [[ -z ${unyn} ]] && unyn="y"
  if [[ ${unyn} != [Yy] ]]; then
    echo "已取消..." && exit 1
  fi
  replay_traffic_while "$config_log/$gor_reply_log"
  echo -e "${Info} gor 启动成功！"
}

edit_config() {
  config
  echo && echo -e "您要配置什么？
 ${Green_font_prefix}1.${Font_color_suffix}  配置流量文件存储目录【${Green_font_prefix}$config_save_dir${Font_color_suffix}】
 ${Green_font_prefix}2.${Font_color_suffix}  配置文件名称格式【${Green_font_prefix}$config_file_format${Font_color_suffix}】
 ${Green_font_prefix}3.${Font_color_suffix}  配置录制时监听的端口【${Green_font_prefix}$config_listen_port${Font_color_suffix}】
 ${Green_font_prefix}4.${Font_color_suffix}  配置录制时分片文件大小限制【${Green_font_prefix}$config_file_size_limit${Font_color_suffix}】
 ${Green_font_prefix}5.${Font_color_suffix}  配置回放流量时的速度【${Green_font_prefix}$config_replay_speed${Font_color_suffix}】
 ${Green_font_prefix}6.${Font_color_suffix}  配置回放流量时的http输出url【${Green_font_prefix}$config_output_http${Font_color_suffix}】
 ${Green_font_prefix}7.${Font_color_suffix}  配置日志记录文件目录【${Green_font_prefix}$config_log${Font_color_suffix}】
 ${Green_font_prefix}8.${Font_color_suffix}  手动编辑配置文件
 ${Green_font_prefix}0.${Font_color_suffix}  取消" && echo
  read -e -p " 请输入数字 [0-7]:" edit_type
  case "$edit_type" in
  0)
    exit 0
    ;;
  1)
    echo && echo -e " 请输入流量文件存储目录" && echo
    read -e -p "(默认:$config_save_dir):" save_dir
    [[ -z "${save_dir}" ]] && echo "已取消..." && exit 1
    do_config 'config_save_dir' "$save_dir"
    ;;
  2)
    echo && echo -e " 请输入文件名称格式" && echo
    read -e -p "(默认:$config_file_format):" file_format
    [[ -z "${file_format}" ]] && echo "已取消..." && exit 1
    do_config 'config_save_dir' "$file_format"
    ;;
  3)
    echo && echo -e " 请输入录制时监听的端口 [1-65535]" && echo
    read -e -p "(默认:$config_listen_port):" listen_port
    [[ -z "${listen_port}" ]] && echo "已取消..." && exit 1
    if [[ $listen_port =~ ^[0-9]+$ && $listen_port -gt 0 && $listen_port -lt 25555 ]]; then
      do_config 'config_save_dir' "$listen_port"
    else
      echo -e "${Error} 格式不正确！"
    fi
    ;;
  4)
    echo && echo -e " 请输入录制时分片文件大小限制" && echo
    read -e -p "(默认:$config_file_size_limit):" file_size
    [[ -z "${file_size}" ]] && echo "已取消..." && exit 1
    if [[ $file_size =~ ^[0-9]+m$ && ${file_size%?} -gt 0 ]]; then
      do_config 'config_file_size_limit' "$file_size"
    else
      echo -e "${Error} 格式不正确！"
    fi
    ;;
  5)
    echo && echo -e " 请输入回放流量时的速度(直接输入百分数，仅支持百分数)" && echo
    read -e -p "(默认:$config_replay_speed):" replay_speed
    [[ -z "${replay_speed}" ]] && echo "已取消..." && exit 1
    if [[ $replay_speed =~ ^[0-9]+%$ && ${replay_speed%?} -gt 0 ]]; then
      do_config 'config_replay_speed' "$replay_speed"
    else
      echo -e "${Error} 格式不正确！"
    fi
    ;;
  6)
    echo && echo -e " 请输入回放流量时的http输出url" && echo
    read -e -p "(默认:$config_output_http):" output_http
    [[ -z "${output_http}" ]] && echo "已取消..." && exit 1
    do_config 'config_output_http' "$output_http"
    ;;
  7)
    echo && echo -e " 请输入日志记录文件目录" && echo
    read -e -p "(默认:$config_log):" log_path
    [[ -z "${log_path}" ]] && echo "已取消..." && exit 1
    do_config 'config_log' "$log_path"
    ;;
  8)
    edit_config_manual
    ;;
  *)
    echo "请输入正确数字 [0-7]"
    ;;
  esac
}

edit_config_manual() {
  echo -e "${Tip} 手动修改配置文件须知：
${Green_font_prefix}1.${Font_color_suffix} 配置文件中含有中文注释，如果你的 服务器系统 或 SSH工具 不支持中文显示，将会乱码(请本地编辑)。
${Green_font_prefix}2.${Font_color_suffix} 一会自动打开配置文件后，就可以开始手动编辑文件了。
${Green_font_prefix}3.${Font_color_suffix} 如果要退出并保存文件，那么按 ${Green_font_prefix}Esc键${Font_color_suffix} 后，输入 ${Green_font_prefix}:wq${Font_color_suffix} 后，再按一下 ${Green_font_prefix}回车键${Font_color_suffix} 即可。
${Green_font_prefix}4.${Font_color_suffix} 如果要退出并不保存文件，那么按 ${Green_font_prefix}Esc键${Font_color_suffix} 后，输入 ${Green_font_prefix}:q!${Font_color_suffix} 即可。
${Green_font_prefix}5.${Font_color_suffix} 如果你想在本地编辑配置文件，那么配置文件位置： ${Green_font_prefix}$gor_config${Font_color_suffix} 。" && echo
  read -e -p "如果已经理解 vim 使用方法，请按任意键继续，如要取消请使用 Ctrl+C 。" var
  vim "$gor_config"
}

show_traffic_file() {
  config
  echo && echo -e "${Info} 已缓存时间片文件" && echo
  echo -e '================================================'
  ls -lh "$config_save_dir" | grep -v 'total' | awk '{print $5, $6, $7, $8, $9}'
  echo -e '================================================'
}

tar_traffic_file() {
  config
  disable_time_split=false
  start_time=''
  end_time=''
  echo && echo -e "格式：yyyy/MM/dd hh:mm:ss"
  echo -e " 请输入回放的开始时间：" && echo
  while [[ "$disable_time_split" == "false" && -z "$start_time" ]]; do
    read -e -p "(回车：压缩全部)" input_start_time
    [[ -z ${input_start_time} ]] && disable_time_split=true
    if [[ "$disable_time_split" == "false" ]]; then
      if [[ $input_start_time =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}\ [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$ ]]; then
        start_time=$(date -d "$input_start_time" +"%s")
        if [[ $? != 0 ]]; then
          echo -e "${Error} 格式不正确，请重新输入！"
          start_time=''
        fi
      else
        echo -e "${Error} 格式不正确，请重新输入！"
        start_time=''
      fi
    fi
  done
  if [[ "$disable_time_split" == "false" ]]; then
    echo -e " 请输入回放的结束时间："
  fi
  while [[ "$disable_time_split" == "false" && -z "$end_time" ]]; do
    read -e -p "(回车：当前时间)" input_end_time
    [[ -z ${input_end_time} ]] && input_end_time=$(date +"%Y/%m/%d %H:%M:%S")
    if [[ $input_end_time =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}\ [0-2][0-9]:[0-5][0-9]:[0-5][0-9]$ ]]; then
      end_time=$(date -d "$input_end_time" +"%s")
      if [[ $? != 0 ]]; then
        echo -e "${Error} 格式不正确，请重新输入！"
        end_time=''
      fi
    else
      echo -e "${Error} 格式不正确，请重新输入！"
      end_time=''
    fi
  done
  start_time_file_name=$(echo $input_start_time | sed 's/\//_/g' | sed 's/:/_/g' | sed 's/ /_/g')
  end_time_file_name=$(echo $input_end_time | sed 's/\//_/g' | sed 's/:/_/g' | sed 's/ /_/g')
  tar_file_name="${start_time_file_name}_${end_time_file_name}.tar"
  file_string=$(ls -rt "$config_save_dir" | tr "\n" " ")
  files=($file_string)
  length=${#files[*]}
  index=0
  touch "$tar_file_name"
  while [[ $index -lt $length ]]; do
    gor_file=${files[$index]}
    file_name=$(echo "$gor_file" | cut -d_ -f1)
    date=$(parse_time "$file_name")
    temp_time=$(date -d "$date" +"%s")
    if [[ "$disable_time_split" == "true" || ($temp_time -ge $start_time && $temp_time -le $end_time) ]]; then
      tar -rvf "$tar_file_name" "$config_save_dir/$gor_file"
    fi
    ((index++))
  done
  gzip "$tar_file_name"
  echo -e "${Info} 打包完成！"
}

view_capture_log() {
  config
  echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat $config_log/$gor_capture_log${Font_color_suffix} 命令。" && echo
  tail -f "$config_log/$gor_capture_log"
}

view_reply_log() {
  config
  echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat $config_log/$gor_reply_log${Font_color_suffix} 命令。" && echo
  tail -f "$config_log/$gor_reply_log"
}

update_shell() {
  sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "https://raw.githubusercontent.com/Mystery0Tools/BashScripts/master/gor/gor.sh" | grep 'sh_ver="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
  [[ -z ${sh_new_ver} ]] && echo -e "${Error} 无法链接到 Github !" && exit 0
  wget -N --no-check-certificate "https://raw.githubusercontent.com/Mystery0Tools/BashScripts/master/gor/gor.sh" && chmod +x gor.sh
  echo -e "脚本已更新为最新版本[ ${sh_new_ver} ] !(注意：因为更新方式为直接覆盖当前运行的脚本，所以可能下面会提示一些报错，无视即可)" && exit 0
}

check_root
check_system $1
check_dir
check_installed_status

echo && echo -e " gor 管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- by Mystery0 --

 ${Green_font_prefix} 0.${Font_color_suffix} 升级脚本
————————————
 ${Green_font_prefix} 1.${Font_color_suffix} 开始录制流量
 ${Green_font_prefix} 2.${Font_color_suffix} 停止当前运行的 gor 进程
 ${Green_font_prefix} 3.${Font_color_suffix} 回放流量
 ${Green_font_prefix} 4.${Font_color_suffix} 修改配置
————————————
 ${Green_font_prefix} 5.${Font_color_suffix} 查看 已缓存时间片文件
 ${Green_font_prefix} 6.${Font_color_suffix} 打包 已缓存时间片文件
 ${Green_font_prefix} 7.${Font_color_suffix} 查看 录制日志信息
 ${Green_font_prefix} 8.${Font_color_suffix} 查看 回放日志信息
————————————
 ${Green_font_prefix} 9.${Font_color_suffix} 退出脚本
————————————" && echo
show_status
echo
read -e -p " 请输入数字 [0-9]:" num
case "$num" in
0)
  update_shell
  ;;
1)
  capture_traffic
  ;;
2)
  stop_capture_traffic
  ;;
3)
  replay_traffic
  ;;
4)
  edit_config
  ;;
5)
  show_traffic_file
  ;;
6)
  tar_traffic_file
  ;;
7)
  view_capture_log
  ;;
8)
  view_reply_log
  ;;
9)
  exit 0
  ;;
*)
  echo "请输入正确数字 [0-7]"
  ;;
esac
