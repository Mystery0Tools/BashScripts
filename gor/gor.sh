#!/usr/bin/env bash
sh_ver="1.0.4"
base_url='https://raw.githubusercontent.com/Mystery0Tools/BashScripts/master/gor'
base_gor_url='https://github.com/Mystery00/goreplay/releases'
gor_mac_url="$base_gor_url/download/v1.0.0-fork/gor_1.0.0-fork_mac.tar.gz"
gor_x64_url="$base_gor_url/download/v1.0.0-fork/gor_1.0.0-fork_x64.tar.gz"
update_url="$base_url/gor.sh"
config_url="$base_url/gor.config.template"
gor='/usr/local/bin/gor'
gor_config='/etc/gor/gor.config'
gor_config_template='gor.config.template'
gor_capture_log='capture.log'
gor_reply_log='reply.log'
# 录制的流量文件名称格式
config_file_format='%Y-%m-%d/%H/%M'
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Yellow_font_prefix="\033[33m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Yellow_background_prefix="\033[43;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"

# 输出进度条 横向
print_progress_bar() {
  local progress=$1
  local extra_message=$2
  local show_str=''
  local progress_cols=$((${COLUMNS} - 17))
  local max_length=100
  if [[ $max_length -gt $progress_cols ]]; then
    max_length=$progress_cols
  fi
  local split=100/$max_length
  local i=0
  while [[ $i -le $max_length ]]; do
    split_progress=$i*$split
    next_progress=$split_progress+$split
    if [[ $progress -ge $next_progress ]]; then
      show_str+="="
    elif [[ $progress -le $split_progress ]]; then
      break
    else
      show_str+="-"
    fi
    ((i++))
  done
  printf "[%-${max_length}s][%d%%]%s\r" "$show_str" "$progress" "$extra_message"
}

# 输出进度条, 小棍型
procing() {
  trap 'exit 0;' 6 # 接收耗时操作执行完毕的信号，用来退出循环
  little_stick=('-' '\' '|' '/')
  little_stick_size=${#little_stick[*]}
  ellipsis=('.' '..' '...' '....' '.....' '......')
  ellipsis_size=${#ellipsis[*]}
  procing_index=0
  while :; do # 无限循环
    tput sc
    tput el
    little_stick_index=$procing_index%$little_stick_size
    ellipsis_index=$procing_index%$ellipsis_size
    printf "%s    %-6s    %s" "${little_stick[$little_stick_index]}" "${ellipsis[$ellipsis_index]}" "${little_stick[$little_stick_index]}"
    sleep 0.5 # 每一秒钟更新一次
    tput rc
    ((procing_index++))
  done
}

# 等待执行完成
waiting() {
  local pid="$1"
  procing &# 后台执行输出小棍子的进程
  local tmppid="$!"               # 获取小棍子进程的pid，用于后续终止
  wait "$pid"                     # 等待耗时操作执行完成
  tput rc                         # 恢复光标到最后保存的位置，替代小棍子
  kill -6 $tmppid >/dev/null 1>&2 # 终止小棍子进程
}

# 执行某些耗时操作
do_something_background() {
  echo -ne "$2  " # 打印执行耗时操作之前的信息文本
  tput civis
  eval "$1" &# 根据第一个参数执行操作
  waiting "$!" # 等待耗时操作执行
  tput cnorm
  tput el
  echo
}

download_file() {
  http_code=$(curl -I -m 10 -o /dev/null -s -w "%{http_code}" "$1")
  [[ $http_code != 200 ]] && echo -e "${Error} 配置文件下载失败！" && exit 1
  curl -# -o "$2" "$1"
}

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
    exit 1
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
    if [[ ! -e ${gor_config_template} ]]; then
      echo -e "${Info} 配置文件模板不存在，正在从仓库中下载..."
      download_file "$config_url" "$gor_config_template"
    fi
    [[ ! -e ${gor_config_template} ]] && echo -e "${Error} 配置模板文件不存在，请检查 !" && exit 1
    cp "$gor_config_template" "$gor_config"
    rm -rf "$gor_config_template"
  fi
}

check_installed_status() {
  if [[ ! -e ${gor} ]]; then
    # 判断当前目录是否存在可执行文件
    case $system in
    'mac')
      if [[ ! -e 'gor_mac' ]]; then
        echo -e "${Tip} gor 没有安装，尝试下载，如果长时间卡在这里，请手动下载!"
        curl -# -o 'gor_mac.tar.gz' "$gor_mac_url" && tar zxf 'gor_mac.tar.gz' && mv gor gor_mac
        echo -e "${Info} gor 下载成功!"
        echo -e "${Info} 正在安装 gor !"
      fi
      if [[ ! -e 'gor_mac' ]]; then
        echo -e "${Error} gor 下载失败，请手动下载 !" && exit 1
      else
        # 当前目录存在，拷贝到 /usr/local/bin 去
        cp -rf 'gor_mac' "$gor"
        rm -rf 'gor_mac'
        echo -e "${Info} gor 安装成功!"
        return 0
      fi
      ;;
    'linux')
      if [[ ! -e 'gor_x64' ]]; then
        echo -e "${Tip} gor 没有安装，尝试下载，如果长时间卡在这里，请手动下载!"
        curl -# -o 'gor_x64.tar.gz' "$gor_x64_url" && tar zxf 'gor_x64.tar.gz' && mv gor gor_x64
        echo -e "${Info} gor 下载成功!"
        echo -e "${Info} 正在安装 gor !"
      fi
      if [[ ! -e 'gor_x64' ]]; then
        echo -e "${Error} gor 下载失败，请手动下载 !" && exit 1
      else
        # 当前目录存在，拷贝到 /usr/local/bin 去
        cp -rf 'gor_x64' "$gor"
        rm -rf 'gor_x64'
        echo -e "${Info} gor 安装成功!"
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
  do_config_no_update "$1" "$2"
  config
}

do_config_no_update() {
  key="$1"
  value="$2"
  sed "s~$key=.*~$key=$value~g" <"$gor_config" >"temp"
  mv "temp" "$gor_config"
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
    do_config 'config_listen_port' "$listen_port"
  fi
  if [[ -n "$config_capture_file_suffix" ]]; then
    filter_regex="$config_save_dir/${config_file_format}_${config_capture_file_suffix}.gor"
  else
    filter_regex="$config_save_dir/${config_file_format}.gor"
  fi
  if [[ "$config_print_debug_log" == "true" ]]; then
    print_debug_log="--verbose --debug"
  else
    print_debug_log=''
  fi
  cmd="$gor --input-raw :$listen_port --output-file=$filter_regex --output-file-queue-limit 0 --output-file-size-limit $config_file_size_limit $print_debug_log"
  (eval "$cmd") >"$config_log/$gor_capture_log" 2>&1 &
  echo -e "${Info} gor 启动成功！"
}

stop_capture_traffic() {
  config
  check_installed_status
  check_pid
  [[ -z ${PID} ]] && echo -e "${Error} gor 没有运行，请检查 !" && exit 1
  if [[ "$config_force_kill_gor" == "true" ]]; then
    kill -9 "$PID"
  else
    kill "$PID"
    echo -e "${Info} gor 已经标记退出，可能需要一段时间才能完全退出..."
  fi
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
}

process_copy_file() {
  tmp_dir='temp_dir_do_not_delete'
  rm -rf "$tmp_dir"
  mkdir "$tmp_dir"
  tar_file_name="tmp.tar"
  if [[ "$disable_time_split" == "true" ]]; then
    tar_file_name='tmp.tar.gz'
  fi
  touch "$tar_file_name"
  if [[ "$disable_time_split" == "true" ]]; then
    do_something_background 'tar_traffic_file_all' "${Info} 正在处理文件  "
  else
    do_something_background 'tar_traffic_file_while' "${Info} 正在处理文件  "
  fi
  tar -zxf 'tmp.tar.gz' --strip-components 1 -C "$tmp_dir/"
  rm -rf 'tmp.tar.gz'
}

replay_traffic_while() {
  log_file=$1
  file_string=$(ls -rt "$config_save_dir" | tr "\n" " ")
  files=($file_string)
  length=${#files[*]}
  process_copy_file
  if [[ ${config_enable_middleware} == "true" ]]; then
    middleware="--middleware '$config_middleware'"
  else
    middleware=''
  fi
  if [[ -n "$config_filter_regex" ]]; then
    filter_regex="--http-allow-url $config_filter_regex"
  else
    filter_regex=''
  fi
  if [[ "$config_print_debug_log" == "true" ]]; then
    print_debug_log="--verbose --debug"
  else
    print_debug_log=''
  fi
  cmd="$gor --input-file '$tmp_dir/*/*/*|$config_replay_speed' --output-http $config_output_http $middleware $filter_regex --http-allow-method GET --http-allow-method POST --http-allow-method PUT --http-allow-method DELETE --http-allow-method PATCH $print_debug_log && rm -rf $tmp_dir"
  (eval "$cmd") >"$log_file" 2>&1 &
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
  filter_regex=''
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
  echo && echo -e " 请输入回放时过滤url请求的正则表达式（为空则跳过指定）" && echo
  read -e -p "(默认:$config_filter_regex):" filter_regex
  [[ -z "${filter_regex}" ]] && filter_regex=$config_filter_regex
  do_config 'config_filter_regex' "$filter_regex"

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
  if [[ ${config_enable_middleware} == "true" ]]; then
    middleware_status='中间件已启用'
  else
    middleware_status='中间件已禁用'
  fi
  echo && echo -e "您要配置什么？
 ${Green_font_prefix} 1.${Font_color_suffix}  配置流量文件存储目录【${Green_font_prefix}$config_save_dir${Font_color_suffix}】
 ${Green_font_prefix} 2.${Font_color_suffix}  配置回放时是否打印详细日志【${Green_font_prefix}$config_print_reply_info_log${Font_color_suffix}】
 ${Green_font_prefix} 3.${Font_color_suffix}  配置录制时监听的端口【${Green_font_prefix}$config_listen_port${Font_color_suffix}】
 ${Green_font_prefix} 4.${Font_color_suffix}  配置录制时分片文件大小限制【${Green_font_prefix}$config_file_size_limit${Font_color_suffix}】
 ${Green_font_prefix} 5.${Font_color_suffix}  配置回放流量时的速度【${Green_font_prefix}$config_replay_speed${Font_color_suffix}】
 ${Green_font_prefix} 6.${Font_color_suffix}  配置回放流量时的http输出url【${Green_font_prefix}$config_output_http${Font_color_suffix}】
 ${Green_font_prefix} 7.${Font_color_suffix}  配置日志记录文件目录【${Green_font_prefix}$config_log${Font_color_suffix}】
 ${Green_font_prefix} 8.${Font_color_suffix}  配置中间件可执行文件路径【${Green_font_prefix}$config_middleware${Font_color_suffix}】($middleware_status)
 ${Green_font_prefix} 9.${Font_color_suffix}  配置录制文件名后缀【${Green_font_prefix}$config_capture_file_suffix${Font_color_suffix}】
 ${Green_font_prefix}10.${Font_color_suffix}  配置回放过滤url请求正则表达式【${Green_font_prefix}$config_filter_regex${Font_color_suffix}】
 ${Green_font_prefix}11.${Font_color_suffix}  手动编辑配置文件
 ${Green_font_prefix}12.${Font_color_suffix}  从服务器或者本地更新配置文件
 ${Green_font_prefix} 0.${Font_color_suffix}  取消" && echo
  read -e -p " 请输入数字 [0-10]:" edit_type
  case "$edit_type" in
  0)
    exit 0
    ;;
  1)
    echo && echo -e " 请输入流量文件存储目录" && echo
    read -e -p "(默认:$config_save_dir):" save_dir
    [[ -z "${save_dir}" ]] && echo "已取消..." && exit 1
    do_config 'config_save_dir' "$save_dir"
    echo -e "${Info} 配置成功！"
    ;;
  2)
    echo && echo -e " 回放时打印详细的日志？(y/N)" && echo
    read -e -p "(默认: n):" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
      do_config 'config_print_reply_info_log' 'true'
    else
      do_config 'config_print_reply_info_log' 'false'
    fi
    echo -e "${Info} 配置成功！"
    ;;
  3)
    echo && echo -e " 请输入录制时监听的端口 [1-65535]" && echo
    read -e -p "(默认:$config_listen_port):" listen_port
    [[ -z "${listen_port}" ]] && echo "已取消..." && exit 1
    if [[ $listen_port =~ ^[0-9]+$ && $listen_port -gt 0 && $listen_port -lt 65535 ]]; then
      do_config 'config_listen_port' "$listen_port"
      echo -e "${Info} 配置成功！"
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
      echo -e "${Info} 配置成功！"
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
      echo -e "${Info} 配置成功！"
    else
      echo -e "${Error} 格式不正确！"
    fi
    ;;
  6)
    echo && echo -e " 请输入回放流量时的http输出url" && echo
    read -e -p "(默认:$config_output_http):" output_http
    [[ -z "${output_http}" ]] && echo "已取消..." && exit 1
    do_config 'config_output_http' "$output_http"
    echo -e "${Info} 配置成功！"
    ;;
  7)
    echo && echo -e " 请输入日志记录文件目录" && echo
    read -e -p "(默认:$config_log):" log_path
    [[ -z "${log_path}" ]] && echo "已取消..." && exit 1
    do_config 'config_log' "$log_path"
    echo -e "${Info} 配置成功！"
    ;;
  8)
    config_middleware=${config_middleware//\'/}
    echo && echo -e " 请输入中间件可执行文件路径" && echo
    read -e -p "(默认:$config_middleware):" middleware
    [[ -z "${middleware}" ]] && echo "已取消..." && exit 1
    [[ ! -e "${middleware}" ]] && echo -e "${Error} 可执行文件不存在，请检查输入..." && exit 1
    do_config 'config_middleware' "'$middleware'"
    echo && echo -e " 是否启用该中间件？(Y/n)" && echo
    read -e -p "(默认: 确认):" unyn
    [[ -z ${unyn} ]] && unyn="y"
    if [[ ${unyn} == [Yy] ]]; then
      do_config 'config_enable_middleware' 'true'
      echo -e "${Info} 中间件已启用！"
    else
      do_config 'config_enable_middleware' 'false'
      echo -e "${Info} 中间件已禁用！"
    fi
    ;;
  9)
    echo && echo -e " 请输入录制时生成的文件名后缀" && echo
    read -e -p "(默认:$config_capture_file_suffix):" capture_file_suffix
    [[ -z "${capture_file_suffix}" ]] && echo "已取消..." && exit 1
    do_config 'config_capture_file_suffix' "$capture_file_suffix"
    echo -e "${Info} 配置成功！"
    ;;
  10)
    echo && echo -e " 请输入回放时过滤url请求的正则表达式" && echo
    read -e -p "(默认:$config_filter_regex):" filter_regex
    [[ -z "${filter_regex}" ]] && echo "已取消..." && exit 1
    do_config 'config_filter_regex' "$filter_regex"
    echo -e "${Info} 配置成功！"
    ;;
  11)
    edit_config_manual
    ;;
  12)
    update_config_file_from_server
    ;;
  *)
    echo "请输入正确数字 [0-9]"
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

update_config_file_from_server() {
  config
  if [[ ! -e ${gor_config_template} ]]; then
    echo -e "${Info} 配置文件模板不存在，正在从仓库中下载..."
    download_file "$config_url" "$gor_config_template"
  fi
  [[ ! -e ${gor_config_template} ]] && echo -e "${Error} 配置模板文件不存在，请检查 !" && exit 1
  cp "$gor_config_template" "$gor_config"
  rm -rf "$gor_config_template"
  do_config_no_update 'config_save_dir' "$config_save_dir"
  do_config_no_update 'config_print_debug_log' "$config_print_debug_log"
  do_config_no_update 'config_listen_port' "$config_listen_port"
  do_config_no_update 'config_file_size_limit' "$config_file_size_limit"
  do_config_no_update 'config_replay_speed' "$config_replay_speed"
  do_config_no_update 'config_output_http' "$config_output_http"
  do_config_no_update 'config_log' "$config_log"
  do_config_no_update 'config_middleware' "'$config_middleware'"
  do_config_no_update 'config_enable_middleware' "$config_enable_middleware"
  do_config_no_update 'config_force_kill_gor' "$config_force_kill_gor"
  do_config_no_update 'config_capture_file_suffix' "$config_capture_file_suffix"
  do_config_no_update 'config_filter_regex' "$config_filter_regex"
  echo -e "${Info} 配置文件更新成功！"
}

show_traffic_file() {
  config
  echo -e "${Tip} 分页查看文件须知：
${Green_font_prefix}1.${Font_color_suffix} 一会自动分页显示之后，可以通过 ${Green_font_prefix}方向键${Font_color_suffix} 或者 ${Green_font_prefix}回车键${Font_color_suffix} 查看后面的数据。
${Green_font_prefix}2.${Font_color_suffix} 如果需要搜索有没有指定名称的文件，那么按 ${Green_font_prefix}/键${Font_color_suffix} 后，输入 ${Green_font_prefix}要搜索的文件名称${Font_color_suffix} 后，再按一下 ${Green_font_prefix}回车键${Font_color_suffix} 即可。
${Green_font_prefix}3.${Font_color_suffix} 如果要退出查看，那么按 ${Green_font_prefix}q键${Font_color_suffix} 即可。" && echo
  read -e -p "如果已经理解 less 使用方法，请按任意键继续，如要取消请使用 Ctrl+C 。" var
  ls -lh "$config_save_dir" | grep -v 'total' | awk '{print $5, $6, $7, $8, $9}' | less
}

tar_traffic_file_while_time_hour() {
  check_start="$1"
  time_minute_dir_string=$(ls -rt "$config_save_dir/$date_dir_name/$time_hour_dir_name" | tr "\n" " ")
  time_minute_dir=()
  time_minute_dir=($time_minute_dir_string)
  time_minute_dir_length=${#time_minute_dir[*]}
  local time_minute_dir_index=0
  while [[ $time_minute_dir_index -lt $time_minute_dir_length ]]; do
    time_minute_dir_name=${time_minute_dir[$time_minute_dir_index]}
    file_name=$(echo "$time_minute_dir_name" | cut -d_ -f1)
    parse_time "$date_dir_name-$time_hour_dir_name-$file_name"
    time_minute_dir_date="$year/$month/$day $hour:$minute:00"
    time_minute_dir_time=$(date -d "$time_minute_dir_date" +"%s")
    if [[ "$check_start" == "true" ]]; then
      if [[ $time_minute_dir_time -ge $start_time ]]; then
        tar -rf "$tar_file_name" "$config_save_dir/$date_dir_name/$time_hour_dir_name/$file_name"*
      fi
    else
      if [[ $time_minute_dir_time -le $end_time ]]; then
        tar -rf "$tar_file_name" "$config_save_dir/$date_dir_name/$time_hour_dir_name/$file_name"*
      fi
    fi
    ((time_minute_dir_index++))
  done
}

tar_traffic_file_while_time() {
  time_hour_dir_string=$(ls -rt "$config_save_dir/$date_dir_name" | tr "\n" " ")
  time_hour_dir=()
  time_hour_dir=($time_hour_dir_string)
  time_hour_dir_length=${#time_hour_dir[*]}
  local time_hour_dir_index=0
  while [[ $time_hour_dir_index -lt $time_hour_dir_length ]]; do
    time_hour_dir_name=${time_hour_dir[$time_hour_dir_index]}
    parse_time "$date_dir_name-$time_hour_dir_name"
    time_hour_dir_date="$year/$month/$day $hour:00:00"
    time_hour_dir_date_start=$(date -d "$input_start_time" +"%Y/%m/%d %H:00:00")
    time_hour_dir_date_end=$(date -d "$input_end_time" +"%Y/%m/%d %H:00:00")
    time_hour_dir_time=$(date -d "$time_hour_dir_date" +"%s")
    if [[ "$time_hour_dir_date" == "$time_hour_dir_date_start" || "$time_hour_dir_date" == "$time_hour_dir_date_end" ]]; then
      # 判断是否是边缘数据
      if [[ "$time_hour_dir_date" == "$time_hour_dir_date_start" ]]; then
        tar_traffic_file_while_time_hour 'true'
      else
        tar_traffic_file_while_time_hour 'false'
      fi
    elif [[ $time_hour_dir_time -gt $start_time && $time_hour_dir_time -lt $end_time ]]; then
      # 不是边缘数据并且在指定时间段中，直接添加所有文件
      tar -rf "$tar_file_name" "$config_save_dir/$date_dir_name/$time_hour_dir_name/"*
    fi
    ((time_hour_dir_index++))
  done
}

tar_traffic_file_while() {
  date_dir_string=$(ls -rt "$config_save_dir" | tr "\n" " ")
  date_dir=()
  date_dir=($date_dir_string)
  date_dir_length=${#date_dir[*]}
  local date_dir_index=0
  while [[ $date_dir_index -lt $date_dir_length ]]; do
    date_dir_name=${date_dir[$date_dir_index]}
    parse_time "$date_dir_name"
    date_dir_date="$year/$month/$day"
    date_dir_date_start=$(date -d "$input_start_time" +"%Y/%m/%d")
    date_dir_date_end=$(date -d "$input_end_time" +"%Y/%m/%d")
    date_dir_time=$(date -d "$date_dir_date" +"%s")
    if [[ "$date_dir_date" == "$date_dir_date_start" || "$date_dir_date" == "$date_dir_date_end" ]]; then
      # 判断是否是边缘数据
      tar_traffic_file_while_time
    elif [[ $date_dir_time -gt $start_time && $date_dir_time -lt $end_time ]]; then
      # 不是边缘数据并且在指定时间段中，直接添加所有文件
      tar -rf "$tar_file_name" "$config_save_dir/$date_dir_name/"*
    fi
    ((date_dir_index++))
  done
  gzip "$tar_file_name"
}

tar_traffic_file_all() {
  tar czf "$tar_file_name" "$config_save_dir"
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
  start_time_file_name=$(echo "$input_start_time" | sed 's/\//_/g' | sed 's/:/_/g' | sed 's/ /_/g')
  end_time_file_name=$(echo "$input_end_time" | sed 's/\//_/g' | sed 's/:/_/g' | sed 's/ /_/g')
  tar_file_name="${start_time_file_name}_${end_time_file_name}.tar"
  if [[ "$disable_time_split" == "true" ]]; then
    tar_file_name='all.tar.gz'
  fi
  touch "$tar_file_name"
  if [[ "$disable_time_split" == "true" ]]; then
    do_something_background 'tar_traffic_file_all' "${Info} 正在处理文件  "
  else
    do_something_background 'tar_traffic_file_while' "${Info} 正在处理文件  "
  fi
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
  sh_new_ver=$(curl -s "$update_url" | grep 'sh_ver="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1)
  [[ -z ${sh_new_ver} ]] && echo -e "${Error} 无法链接到 Gitlab !" && exit 0
  curl -# -o 'gor.sh' "$update_url" && chmod +x gor.sh
  echo -e "脚本已更新为最新版本[ ${Red_font_prefix}${sh_new_ver}${Font_color_suffix} ] !(注意：因为更新方式为直接覆盖当前运行的脚本，所以可能下面会提示一些报错，无视即可)" && exit 0
}

check_root

do_convert() {
  config
  file_string=$(ls -rt "$config_save_dir" | tr "\n" " ")
  files=($file_string)
  length=${#files[*]}
  local progress_label=('-' '\' '|' '/')
  local progress_label_size=${#progress_label[*]}
  local index=0
  local temp_convert_dir_do_not_delete='temp_convert_dir_do_not_delete'
  mkdir "$temp_convert_dir_do_not_delete"
  echo -e "${Info} 正在处理文件..."
  tput civis
  while [[ $index -lt $length ]]; do
    current_progress=$(($index * 100 / $length))
    progress_label_index=$index%$progress_label_size
    print_progress_bar "$current_progress" "[$(($index + 1))/$length]${progress_label[$progress_label_index]}"
    gor_file=${files[$index]}
    file_name=$(echo "$gor_file" | cut -d_ -f1)
    file_name_1=$(echo "$gor_file" | cut -d_ -f2)
    parse_time "$file_name" # 解析文件名的日期时间
    true_file_name_date="$temp_convert_dir_do_not_delete/$year-$month-$day"
    true_file_name_date_hour="$true_file_name_date/$hour"
    true_file_name="$true_file_name_date_hour/${minute}_$file_name_1"
    [[ ! -e "$true_file_name_date" ]] && mkdir "$true_file_name_date"
    [[ ! -e "$true_file_name_date_hour" ]] && mkdir "$true_file_name_date_hour"
    mv "$config_save_dir/$gor_file" "$true_file_name"
    ((index++))
  done
  tput cnorm
  rm -rf "$config_save_dir"
  mv "$temp_convert_dir_do_not_delete" "$config_save_dir"
  echo -e "${Info} 文件处理完成！"
}

case "$1" in
'clear')
  rm -rf "$gor_config"
  rm -rf '/etc/gor'
  rm -rf '/var/log/gor'
  echo -e "${Tip} 要卸载 gor 吗?  (y/N)"
  read -e -p "(默认: n):" unyn
  [[ -z ${unyn} ]] && unyn="n"
  if [[ ${unyn} == [Yy] ]]; then
    rm -rf "$gor"
  fi
  echo -e "${Info} 清理完成！"
  exit 0
  ;;
'convert')
  echo -e "${Tip} 要执行录制文件转换操作吗？重复执行转换可能会出现异常  (y/N)"
  read -e -p "(默认: n):" unyn
  [[ -z ${unyn} ]] && unyn="n"
  if [[ ${unyn} == [Yy] ]]; then
    do_convert
  fi
  exit 0
  ;;
esac

check_system
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
  echo "请输入正确数字 [0-9]"
  ;;
esac
