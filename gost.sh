#!/usr/bin/env bash

Folder="/usr/local/gost"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		yum install python3 -y
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		apt-get install python3 -y
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		apt-get install python3 -y
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		yum install python3 -y
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		apt-get install python3 -y
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		apt-get install python3 -y
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		yum install python3 -y
		release="centos"
	fi
	bit=`uname -m`
}

check_pid(){
	PID=`ps -ef | grep "gost" | grep -v "grep" | grep -v "gost.sh"| grep -v "init.d" | grep -v "service" | awk '{print $2}'`
}

get_ip(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}

check_new_ver(){
	echo -e "${Info} 正在获取 Gost 最新版本"
	if [[ -z ${gost_new_ver} ]]; then
		gost_new_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/ginuerzh/gost/releases | grep -o '"tag_name": ".*"' |head -n 1| sed 's/"//g;s/v//g' | sed 's/tag_name: //g')
		if [[ -z ${gost_new_ver} ]]; then
			echo -e "${Error} gost 最新版本获取失败，请手动获取最新版本号[ https://github.com/ginuerzh/gost/releases ]"
			read -e -p "请输入版本号 [ 格式如 1.34.0 ] :" gost_new_ver
			[[ -z "${gost_new_ver}" ]] && echo "取消..." && exit 1
		else
			echo -e "${Info} 检测到 gost 最新版本为 [ ${gost_new_ver} ]"
		fi
	else
		echo -e "${Info} 即将下载 gost 版本： [ ${gost_new_ver} ]"
	fi
}

check_install_status(){
	[[ ! -e "/usr/bin/gost" ]] && echo -e "${Error} gost 没有安装，请检查 !" && exit 1
	[[ ! -e "/root/.gost/config.json" ]] && echo -e "${Error} gost 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
}

download_gost(){
	if [[ ${bit} == "x86_64" ]]; then
		bit="amd64"
	elif [[ ${bit} == "i386" || ${bit} == "i686" ]]; then
		bit="386"
	else
		bit="arm64"
	fi
	wget -N --no-check-certificate "https://yunpan.sk222.cf/Cloud/gost.gz"
	gost_name="gost"
	
	[[ ! -s "${gost_name}.gz" ]] && echo -e "${Error} gost 压缩包下载失败 !" && exit 1
	gzip -d "${gost_name}.gz"
	[[ ! -e "/root/${gost_name}" ]] && echo -e "${Error} gost 解压失败 !" && exit 1
	mkdir "${Folder}" && mv "${gost_name}" "${Folder}/gost"
	[[ ! -e "${Folder}" ]] && echo -e "${Error} gost 文件夹重命名失败 !" && rm -rf "/usr/local/${gost_name}" && exit 1
	cd "${Folder}"
	chmod +x gost
	cp gost /usr/bin/gost
	mkdir /root/.gost
	wget --no-check-certificate https://raw.githubusercontent.com/ooxoop/gost-install/master/config.json.example -O /root/.gost/config.json
	echo -e "${Info} gost 主程序安装完毕！开始配置服务文件..."
}

service_gost(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ooxoop/gost-install/master/gost_centos.service -O /etc/init.d/gost; then
			echo -e "${Error} gost服务 管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/gost
		chkconfig --add gost
		chkconfig gost on
	else
		if ! wget --no-check-certificate https://raw.githubusercontent.com/ooxoop/gost-install/master/gost_debian.service -O /etc/init.d/gost; then
			echo -e "${Error} gost服务 管理脚本下载失败 !" && exit 1
		fi
		chmod +x /etc/init.d/gost
		update-rc.d -f gost defaults
	fi
	echo -e "${Info} gost服务 管理脚本安装完毕 !"
}

config_gost_l(){
	echo -e "请选择你要进行的操作 

${Green_font_prefix}1.${Font_color_suffix} 清除并重新设置 -L参数
${Green_font_prefix}2.${Font_color_suffix} 增加 -L参数" && echo
	read -e -p "(默认：取消) " l_code
	[[ -z "${l_code}" ]] && l_code="0"
	if [[ ${l_code} == "1" ]]; then
		if [ `grep -c "ServeNodes" /root/.gost/config.json` -eq '0' ]; then
			echo "配置文件中ServeNodes不存在"
		else
			python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));del j['ServeNodes'];json.dump(j,open(\"/root/.gost/config.json\",'w'))"
			config_gost_l_add
		fi
	elif [[ ${l_code} == "2" ]]; then
		config_gost_l_add
	else
		exit 1
	fi
	echo -e "${Info} -L参数 已设置完毕"
}

config_gost_f(){
	echo -e "请选择你要进行的操作 

${Green_font_prefix}1.${Font_color_suffix} 清除并重新设置 -F参数
${Green_font_prefix}2.${Font_color_suffix} 增加 -F参数
${Green_font_prefix}3.${Font_color_suffix} 不使用 -F参数" && echo
	read -e -p "(默认：取消) " f_code
	[[ -z "${f_code}" ]] && f_code="0"
	if [[ ${f_code} == "1" ]]; then
		if [ `grep -c "ChainNodes" /root/.gost/config.json` -eq '0' ]; then
			echo "配置文件中ChainNodes不存在"
		else
			python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));del j['ChainNodes'];json.dump(j,open(\"/root/.gost/config.json\",'w'))"
			config_gost_f_add
		fi
	elif [[ ${f_code} == "2" ]]; then
		config_gost_f_add
	elif [[ ${f_code} == "3" ]]; then
		python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));del j['ChainNodes'];json.dump(j,open(\"/root/.gost/config.json\",'w'))"
	else
		exit 1
	fi
}

config_gost_l_add(){
	echo -e "请输入 -L 参数"
	read -e -p "(默认 - [tcp://:6666]): " param_l
	[[ -z "$param_l" ]] && param_l="tcp://:6666"
	if [ `grep -c "ServeNodes" /root/.gost/config.json` -eq '0' ]; then
		python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));a = {'ServeNodes':['$param_l']};j.update(a);print (j['ServeNodes']);json.dump(j,open(\"/root/.gost/config.json\",'w'))" && echo -e "${Info} 配置更新成功"
	else
		python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));j['ServeNodes'].append( \"$param_l\");print (j['ServeNodes']);json.dump(j,open(\"/root/.gost/config.json\",'w'))" && echo -e "${Info} 配置更新成功"
	fi
	echo -e "是否继续添加 -L 参数 (0:取消/1:继续)"
	read -e -p "(默认：取消) " l_add_code
	[[ -z "${l_add_code}" ]] && l_add_code="0"
	if [[ ${l_add_code} == "1" ]]; then
		param_l="tcp://:6666"
		config_gost_l_add
	fi
}

config_gost_f_add(){
	echo -e "请输入 -F 参数"
	read -e -p "(默认 - [tcp://:6666]): " param_f
	[[ -z "$param_f" ]] && param_f="tcp://:6666"
	if [ `grep -c "ChainNodes" /root/.gost/config.json` -eq '0' ]; then
		python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));a = {'ChainNodes':['$param_f']};j.update(a);print (j['ServeNodes']);json.dump(j,open(\"/root/.gost/config.json\",'w'))" && echo -e "${Info} 配置更新成功"
	else
		python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));j['ChainNodes'].append( \"$param_f\");print (j['ServeNodes']);json.dump(j,open(\"/root/.gost/config.json\",'w'))" && echo -e "${Info} 配置更新成功"
	fi
	echo -e "是否继续添加 -F 参数 (0:取消/1:继续)"
	read -e -p "(默认：取消) " f_add_code
	[[ -z "${f_add_code}" ]] && f_add_code="0"
	if [[ ${f_add_code} == "1" ]]; then
		param_f="tcp://:6666"
		config_gost_f_add
	fi
}

View_config(){
	echo -e "${Info} -L参数为"
	python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));print (j['ServeNodes'])"
	if [ `grep -c "ChainNodes" /root/.gost/config.json` -eq '0' ]; then
		exit 1
	else
		echo -e "${Info} -F参数为"
		python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));print (j['ChainNodes'])" 
	fi
}

Set_config(){
	echo && echo -e "gost 配置菜单
————————————————————————
${Green_font_prefix}1.${Font_color_suffix} 设置-L参数
${Green_font_prefix}2.${Font_color_suffix} 设置-F参数" && echo
	read -e -p "(默认：取消) " config_code
	[[ -z "${config_code}" ]] && config_code="0"
	if [[ ${config_code} == "1" ]]; then
		config_gost_l
		Restart_gost
	elif [[ ${config_code} == "2" ]]; then
		config_gost_f
		Restart_gost
	else
		exit 1
	fi
}

Install_gost(){
	check_sys
	check_new_ver
	download_gost
	service_gost
	echo -e "${Info} gost 已安装完成！请重新运行脚本进行配置~"
}

Remove_gost(){
	Stop_gost
	rm -rf "$Folder" && rm -rf /root/.gost && rm -rf /etc/init.d/gost
	echo -e "${Info} gost 已卸载完成！"
}

Start_gost(){
	check_install_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} gost 正在运行，请检查 !" && exit 1
	/etc/init.d/gost start
	View_config
}

Stop_gost(){
	check_install_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} gost 没有运行，请检查 !" && exit 1
	/etc/init.d/gost stop
}

Restart_gost(){
	check_install_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/gost stop
	/etc/init.d/gost start
	View_config
}


echo && echo -e " gost 一键安装管理脚本beta ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
 -- 四分体 | sifenti.com --

${Green_font_prefix} 1.${Font_color_suffix} 安装 gost
${Green_font_prefix} 2.${Font_color_suffix} 卸载 gost
————————————————————————
${Green_font_prefix} 3.${Font_color_suffix} 启动 gost
${Green_font_prefix} 4.${Font_color_suffix} 停止 gost
${Green_font_prefix} 5.${Font_color_suffix} 重启 gost
————————————————————————
${Green_font_prefix} 6.${Font_color_suffix} 设置 快速配置
${Green_font_prefix} 7.${Font_color_suffix} 查看 当前配置
${Green_font_prefix} 8.${Font_color_suffix} 打开 配置文件
${Green_font_prefix} 9.${Font_color_suffix} 日志 输出日志
————————————————————————" && echo
if [[ -e "/usr/local/gost/gost" ]]; then
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
	fi
else
	echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo
read -e -p " 请输入数字 [0-10]: " num
case "$num" in
	1)
	Install_gost
	;;
	2)
	Remove_gost
	;;
	3)
	Start_gost
	;;
	4)
	Stop_gost
	;;
	5)
	Restart_gost
	;;
	6)
	Set_config
	;;
	7)
	View_config
	;;
	8)
	vi /root/.gost/config.json
	Restart_gost
	;;
	9)
	tail -n 50 /root/.gost/gost.log
	;;
	*)
	echo "请输入正确数字 [0-10]"
	;;
esac


