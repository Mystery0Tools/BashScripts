#!/bin/bash

#
# 该脚本参考了Toyo的脚本源码
#

sh_ver="1.0.0"
frpc="/usr/bin/frpc"
frpc_conf="/etc/frp/frpc.ini"
frpc_log="/var/log/frp/frpc.log"
frpc_service="/lib/systemd/system/frpc.service"
frpc_service1="/lib/systemd/system/frpc@.service"
frps="/usr/bin/frps"
frps_conf="/etc/frp/frps.ini"
frps_log="/var/log/frp/frps.log"
frps_service="/lib/systemd/system/frps.service"
frps_service1="/lib/systemd/system/frps@.service"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

check_installed_status_no_exit(){
    case "$1" in
        'frpc')
	        [[ -e ${frpc} ]] && has_frpc="true"
        ;;
        'frps')
	        [[ -e ${frps} ]] && has_frps="true"
        ;;
    esac
}

check_installed_status(){
    case "$1" in
        'frpc')
	        [[ ! -e ${frpc} ]] && echo -e "${Error} frpc 没有安装，请检查 !" && exit 1
	        [[ ! -e ${frps_conf} ]] && echo -e "${Error} frpc 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
        ;;
        'frps')
	        [[ ! -e ${frps} ]] && echo -e "${Error} frps 没有安装，请检查 !" && exit 1
	        [[ ! -e ${frps_conf} ]] && echo -e "${Error} frps 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
        ;;
    esac
}

check_pid(){
	PID=`ps -ef| grep "$1"| grep -v grep| grep -v "frp.sh"| grep -v "init.d"| grep -v "service"| awk '{print $2}'`
}

check_system(){
    bit=`uname -m`
    if [[ ${bit} == "armv7l" ]];then
        release="arm"
	elif [[ ${bit} == "x86_64" ]]; then
		release="amd64"
	elif [[ ${bit} == "i386" || ${bit} == "i686" ]]; then
		release="386"
    fi
}

check_new_ver(){
	echo -e "${Info} 请输入 frp 版本号，格式如：[ 1.34.0 ]，获取地址：[ https://github.com/fatedier/frp/releases ]"
	read -e -p "默认回车自动获取最新版本号:" frp_new_ver
	if [[ -z ${frp_new_ver} ]]; then
		frp_new_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/fatedier/frp/releases | grep -o '"tag_name": ".*"' |head -n 1| sed 's/"//g;s/v//g' | sed 's/tag_name: //g')
		if [[ -z ${frp_new_ver} ]]; then
			echo -e "${Error} frp 最新版本获取失败，请手动获取最新版本号[ https://github.com/fatedier/frp/releases ]"
			read -e -p "请输入版本号 [ 格式如 1.34.0 ] :" frp_new_ver
			[[ -z "${frp_new_ver}" ]] && echo "取消..." && exit 1
		else
			echo -e "${Info} 检测到 frp 最新版本为 [ ${frp_new_ver} ]"
		fi
	else
		echo -e "${Info} 即将准备下载 frp 版本为 [ ${frp_new_ver} ]"
	fi
}

update_frp(){
	check_installed_status_no_exit "frpc"
	if [[ $has_frpc != "true" ]];then
		echo -e "${Error} frpc 没有安装 !"
	fi
	check_installed_status_no_exit "frps"
	if [[ $has_frps != "true" ]];then
		echo -e "${Error} frps 没有安装 !"
	fi
	check_new_ver
	if [[ $has_frpc == "true" ]];then
    	install_frpc="true"
		stop_frp "frpc"
	fi
	if [[ $has_frps == "true" ]];then
    	install_frps="true"
		stop_frp "frps"
	fi
    download_frp
    copy_binary
	if [[ $has_frpc == "true" ]];then
		start_frp "frpc"
	fi
	if [[ $has_frps == "true" ]];then
		start_frp "frps"
	fi
}

download_frp(){
    cd "/tmp"
    wget -N --no-check-certificate "https://github.com/fatedier/frp/releases/download/v${frp_new_ver}/frp_${frp_new_ver}_linux_${release}.tar.gz"
    frp_name="frp_${frp_new_ver}_linux_${release}"

    [[ ! -s "${frp_name}.tar.gz" ]] && echo -e "${Error} frp 压缩包下载失败 !" && exit 1
    tar -zxvf "$frp_name.tar.gz"
    [[ ! -e "/tmp/${frp_name}" ]] && echo -e "${Error} frp 解压失败 !" && rm -rf "${frp_name}.tar.gz" && exit 1
    frp_dir_path="/tmp/$frp_name"
}

copy_binary(){
    if [[ ${install_frpc} == "true" ]]; then
        # 安装frpc
        mv "$frp_dir_path/frpc" "$frpc"
        if [[ ! -s "${frpc_conf}" ]];then
            # 复制配置文件
            mv "$frp_dir_path/frpc.ini" "$frpc_conf"
        fi
        mv "$frp_dir_path/systemd/frpc.service" "$frpc_service"
        mv "$frp_dir_path/systemd/frpc@.service" "$frpc_service1"
    fi
    if [[ ${install_frps} == "true" ]]; then
        # 安装frps
        mv "$frp_dir_path/frps" "$frps"
        if [[ ! -s "${frps_conf}" ]];then
            # 复制配置文件
            mv "$frp_dir_path/frps.ini" "$frps_conf"
        fi
        mv "$frp_dir_path/systemd/frps.service" "$frps_service"
        mv "$frp_dir_path/systemd/frps@.service" "$frps_service1"
    fi
}

start_frp_switch(){
	echo && echo -e "你要启动什么？
 ${Green_font_prefix}1.${Font_color_suffix}  仅启动frpc
 ${Green_font_prefix}2.${Font_color_suffix}  仅启动frps
 ${Green_font_prefix}3.${Font_color_suffix}  两个都启动" && echo
    read -e -p "(默认: 取消):" install_type
	[[ -z "${install_type}" ]] && echo "已取消..." && exit 1
	if [[ ${install_type} == "1" ]]; then
        start_frp "frpc"
	elif [[ ${install_type} == "2" ]]; then
        start_frp "frps"
	elif [[ ${install_type} == "3" ]]; then
        start_frp "frpc"
        start_frp "frps"
	else
		echo -e "${Error} 请输入正确的数字(1-3)" && exit 1
	fi
}

start_frp(){
	check_installed_status "$1"
	check_pid "$1"
	[[ ! -z ${PID} ]] && echo -e "${Error} $1 正在运行，请检查 !" && exit 1
	service "$1" start
}

stop_frp_switch(){
	echo && echo -e "你要停止什么？
 ${Green_font_prefix}1.${Font_color_suffix}  仅停止frpc
 ${Green_font_prefix}2.${Font_color_suffix}  仅停止frps
 ${Green_font_prefix}3.${Font_color_suffix}  两个都停止" && echo
    read -e -p "(默认: 取消):" install_type
	[[ -z "${install_type}" ]] && echo "已取消..." && exit 1
	if [[ ${install_type} == "1" ]]; then
        stop_frp "frpc"
	elif [[ ${install_type} == "2" ]]; then
        stop_frp "frps"
	elif [[ ${install_type} == "3" ]]; then
        stop_frp "frpc"
        stop_frp "frps"
	else
		echo -e "${Error} 请输入正确的数字(1-3)" && exit 1
	fi
}

stop_frp(){
	check_installed_status "$1"
	check_pid "$1"
	[[ -z ${PID} ]] && echo -e "${Error} $1 没有运行，请检查 !" && exit 1
	service "$1" stop
}

restart_frp_switch(){
	echo && echo -e "你要重启什么？
 ${Green_font_prefix}1.${Font_color_suffix}  仅重启frpc
 ${Green_font_prefix}2.${Font_color_suffix}  仅重启frps
 ${Green_font_prefix}3.${Font_color_suffix}  两个都重启" && echo
    read -e -p "(默认: 取消):" install_type
	[[ -z "${install_type}" ]] && echo "已取消..." && exit 1
	if [[ ${install_type} == "1" ]]; then
        restart_frp "frpc"
	elif [[ ${install_type} == "2" ]]; then
        restart_frp "frps"
	elif [[ ${install_type} == "3" ]]; then
        restart_frp "frpc"
        restart_frp "frps"
	else
		echo -e "${Error} 请输入正确的数字(1-3)" && exit 1
	fi
}

restart_frp(){
	check_installed_status "$1"
	check_pid "$1"
	[[ ! -z ${PID} ]] && service "$1" stop
	service "$1" start
}

view_Log_switch(){
	echo && echo -e "你要查看什么的日志？
 ${Green_font_prefix}1.${Font_color_suffix}  frpc
 ${Green_font_prefix}2.${Font_color_suffix}  frps" && echo
    read -e -p "(默认: 取消):" install_type
	[[ -z "${install_type}" ]] && echo "已取消..." && exit 1
	if [[ ${install_type} == "1" ]]; then
        view_Log "frpc"
	elif [[ ${install_type} == "2" ]]; then
        view_Log "frps"
	else
		echo -e "${Error} 请输入正确的数字(1-2)" && exit 1
	fi
}

view_Log(){
    case "$1" in
        'frpc')
	        [[ ! -e ${frpc_log} ]] && echo -e "${Error} frpc 日志文件不存在 !" && exit 1
	        echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${frpc_log}${Font_color_suffix} 命令。" && echo
	        tail -f ${frpc_log}
        ;;
        'frps')
	        [[ ! -e ${frpc_log} ]] && echo -e "${Error} frps 日志文件不存在 !" && exit 1
	        echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${frpc_log}${Font_color_suffix} 命令。" && echo
	        tail -f ${frpc_log}
        ;;
    esac
}

install_frp_switch(){
	echo && echo -e "你要安装什么？
 ${Green_font_prefix}1.${Font_color_suffix}  仅安装frpc
 ${Green_font_prefix}2.${Font_color_suffix}  仅安装frps
 ${Green_font_prefix}3.${Font_color_suffix}  两个都安装" && echo
    read -e -p "(默认: 取消):" install_type
	[[ -z "${install_type}" ]] && echo "已取消..." && exit 1
	if [[ ${install_type} == "1" ]]; then
		check_installed_status_no_exit "frpc"
		if [[ ${has_frpc} == "true" ]];then
			echo -e "${Error} frpc 已安装" && exit 1
		fi
		check_new_ver
        download_frp
        install_frpc="true"
        copy_binary
	elif [[ ${install_type} == "2" ]]; then
		check_installed_status_no_exit "frps"
		if [[ ${has_frps} == "true" ]];then
			echo -e "${Error} frps 已安装" && exit 1
		fi
		check_new_ver
        download_frp
        install_frps="true"
        copy_binary
	elif [[ ${install_type} == "3" ]]; then
		check_installed_status_no_exit "frpc"
		if [[ ${has_frpc} == "true" ]];then
			echo -e "${Error} frpc 已安装" && exit 1
		fi
		check_installed_status_no_exit "frps"
		if [[ ${has_frps} == "true" ]];then
			echo -e "${Error} frps 已安装" && exit 1
		fi
		check_new_ver
        download_frp
        install_frpc="true"
        install_frps="true"
        copy_binary
	else
		echo -e "${Error} 请输入正确的数字(1-3)" && exit 1
	fi
}

uninstall_frp_switch(){
	echo && echo -e "你要卸载什么？
 ${Green_font_prefix}1.${Font_color_suffix}  仅卸载frpc
 ${Green_font_prefix}2.${Font_color_suffix}  仅卸载frps
 ${Green_font_prefix}3.${Font_color_suffix}  两个都卸载" && echo
    read -e -p "(默认: 取消):" install_type
	[[ -z "${install_type}" ]] && echo "已取消..." && exit 1
	if [[ ${install_type} == "1" ]]; then
        uninstall_frp "frpc"
	elif [[ ${install_type} == "2" ]]; then
        uninstall_frp "frps"
	elif [[ ${install_type} == "3" ]]; then
        uninstall_frp "frpc"
        uninstall_frp "frps"
	else
		echo -e "${Error} 请输入正确的数字(1-3)" && exit 1
	fi
}

uninstall_frp(){
	check_installed_status
	echo "确定要卸载 $1 ? (y/N)"
	echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid "$1"
		[[ ! -z $PID ]] && kill -9 ${PID}
        case "$1" in
            'frpc')
                rm -rf "${frpc}"
                rm -rf "${frpc_conf}"
                rm -rf "${frpc_service}"
                rm -rf "${frpc_service1}"
            ;;
            'frps')
                rm -rf "${frps}"
                rm -rf "${frps_conf}"
                rm -rf "${frps_service}"
                rm -rf "${frps_service1}"
            ;;
        esac
		rm -rf "${frpc}"
		rm -rf "${Folder}"
		rm -rf "${file}"
		echo && echo "$1 卸载完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
}

edit_frp_conf(){
	echo -e "${Tip} 手动修改配置文件须知：
${Green_font_prefix}1.${Font_color_suffix} 配置文件中含有中文注释，如果你的 服务器系统 或 SSH工具 不支持中文显示，将会乱码(请本地编辑)。
${Green_font_prefix}2.${Font_color_suffix} 一会自动打开配置文件后，就可以开始手动编辑文件了。
${Green_font_prefix}3.${Font_color_suffix} 如果要退出并保存文件，那么按 ${Green_font_prefix}Ctrl+X键${Font_color_suffix} 后，输入 ${Green_font_prefix}y${Font_color_suffix} 后，再按一下 ${Green_font_prefix}回车键${Font_color_suffix} 即可。
${Green_font_prefix}4.${Font_color_suffix} 如果要退出并不保存文件，那么按 ${Green_font_prefix}Ctrl+X键${Font_color_suffix} 后，输入 ${Green_font_prefix}n${Font_color_suffix} 即可。
${Green_font_prefix}5.${Font_color_suffix} 如果你想在本地编辑配置文件，那么配置文件位置： ${Green_font_prefix}/etc/frp/$1.ini${Font_color_suffix} (注意是隐藏目录) 。" && echo
	read -e -p "如果已经理解 nano 使用方法，请按任意键继续，如要取消请使用 Ctrl+C 。" var
    case "$1" in
        'frpc')
			nano "${frpc_conf}"
        ;;
        'frps')
			nano "${frps_conf}"
        ;;
    esac
}

edit_frp_conf_switch(){
	echo && echo -e "你要编辑什么的配置文件？
 ${Green_font_prefix}1.${Font_color_suffix}  frpc
 ${Green_font_prefix}2.${Font_color_suffix}  frps" && echo
    read -e -p "(默认: 取消):" install_type
	[[ -z "${install_type}" ]] && echo "已取消..." && exit 1
	if [[ ${install_type} == "1" ]]; then
        edit_frp_conf "frpc"
	elif [[ ${install_type} == "2" ]]; then
        edit_frp_conf "frps"
	else
		echo -e "${Error} 请输入正确的数字(1-2)" && exit 1
	fi
}

show_status(){
    case "$1" in
        'frpc')
            if [[ -e ${frpc} ]];then
                check="true"
            fi
        ;;
        'frps')
            if [[ -e ${frps} ]];then
                check="true"
            fi
        ;;
    esac
    if [[ ${check} == "true" ]]; then
	    check_pid "$1"
	    if [[ ! -z "${PID}" ]]; then
	    	echo -e "$1 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
	    else
	    	echo -e "$1 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
	    fi
    else
	    echo -e "$1 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
    fi
}

check_root
check_system
mkdir '/etc/frp'
mkdir '/var/log/frp'
echo && echo -e " frp 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- by Mystery0 --
  
 ${Green_font_prefix} 0.${Font_color_suffix} 升级脚本
————————————
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 frp
 ${Green_font_prefix} 2.${Font_color_suffix} 更新 frp
 ${Green_font_prefix} 3.${Font_color_suffix} 卸载 frp
————————————
 ${Green_font_prefix} 4.${Font_color_suffix} 启动 frp
 ${Green_font_prefix} 5.${Font_color_suffix} 停止 frp
 ${Green_font_prefix} 6.${Font_color_suffix} 重启 frp
————————————
 ${Green_font_prefix} 7.${Font_color_suffix} 修改 配置文件
 ${Green_font_prefix} 8.${Font_color_suffix} 查看 日志信息
————————————
 ${Green_font_prefix}10.${Font_color_suffix} 退出脚本
————————————" && echo
show_status frpc
show_status frps
echo
read -e -p " 请输入数字 [0-10]:" num
case "$num" in
	0)
	# Update_Shell
	;;
	1)
	install_frp_switch
	;;
	2)
	update_frp
	;;
	3)
	uninstall_frp_switch
	;;
	4)
	start_frp_switch
	;;
	5)
	stop_frp_switch
	;;
	6)
	restart_frp_switch
	;;
	7)
	edit_frp_conf_switch
	;;
	8)
	view_Log_switch
	;;
	10)
    exit 0
	;;
	*)
	echo "请输入正确数字 [0-10]"
	;;
esac
