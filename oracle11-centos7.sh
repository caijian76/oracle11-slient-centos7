#!/bin/bash
#Create by Kingosoft Caijian

function continue {
while true;do
  read -s -e  -n1 -p "$1[Y/N]?" answer
  case $answer in
  Y | y)
        break;;
  N | n)
        exit 1;;
  esac
done
}

#检测网络链接畅通
function network()
{
    #超时时间
    local timeout=3

    #目标网站
    local target=www.baidu.com

    #获取响应状态码
    local ret_code=`curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1`

    if [ "x$ret_code" = "x200" ]; then
        #网络畅通
        return 0
    else
        #网络不畅通
        return 1
    fi

}

# 创建用户、组、安装目录
function add_user_dir {
	grep oinstall /etc/group >& /dev/null
	if [ $? -ne 0 ] ; then
			groupadd oinstall
			echo -e "\033[32m组oinstall创建完成\033[0m"
	else
	  echo -e "\033[31m组oinstall已经存在，请手动删除(groupdel oinstall)。\033[0m"		
	  exit 1
	fi
	
	grep dba /etc/group >& /dev/null
	if [ $? -ne 0 ] ; then
			groupadd dba
			echo -e "\033[32m组dba创建完成\033[0m"
	else
	  echo -e "\033[31m组dba已经存在，请手动删除(groupdel dba)。\033[0m"
	  exit 1		
	fi
	
	grep oracle /etc/passwd >& /dev/null
	if [ $? -ne 0 ] ; then
			useradd -g oinstall -G dba -d /home/oracle oracle
			echo -e "\033[32m用户oracle创建完成\033[0m"
			echo oracle:$oraclepw | chpasswd
			echo -e "\033[32m用户oracle密码修改完成\033[0m"
	else
	    echo -e "\033[31m用户oracle已经存在，请手动删除(userdel -r oracle)\033[0m"
	    exit 1		
	fi
	    

	if [ ! -d $oraclebase ] ; then
		mkdir -p $oraclehome
		mkdir -p $oraclebase/oradata
		mkdir -p $oraclebase/oraInventory
		chown -R oracle:oinstall $oraclebase
		echo -e "\033[32m相关目录创建完成\033[0m"
	else
		echo -e "\033[31m目录$oraclebase已经存在，请手动清空。\033[0m"
		exit 1
	fi	
}


#修改sysctl参数文件
function change_kernel {
	let shmmax=$mem*1024*8/10
	let shmall=$shmmax/4096
	do_edit fs.aio-max-nr 1048576
	do_edit fs.file-max 6815744
	do_edit kernel.shmmax  $shmmax
	do_edit kernel.shmall  $shmall
	do_edit kernel.shmmni  4096
	do_edit kernel.sem  "250 32000 100 128"
	do_edit net.ipv4.ip_local_port_range  "9000 65500"
	do_edit net.core.rmem_default  262144
	do_edit net.core.rmem_max  4194304
	do_edit net.core.wmem_default  262144
	do_edit net.core.wmem_max  1048586
	sysctl -p >& /dev/null
	echo -e "\033[32m应用sysctl.conf完成\033[0m"
}

function do_edit() {
	grep $1 /etc/sysctl.conf >& /dev/null
	if [ $? -ne 0 ] ; then
		echo "$1=$2" >> /etc/sysctl.conf
		echo -e "\033[32m添加$1=$2到sysctl.conf完成\033[0m" 
	else	
		sed -i "s/^\s*$1.*$/$1=$2/" /etc/sysctl.conf	
		echo -e "\033[33m修改$1=$2到sysctl.conf完成\033[0m"
	fi	
}


#修改limit参数文件
function change_limit {
	grep oracle /etc/security/limits.conf >& /dev/null
	if [ $? -ne 0 ] ; then
		cat  >> /etc/security/limits.conf <<EOF
# add by kingosoft
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
EOF
		echo -e "\033[32m配置limit.conf完成\033[0m"
	else	
		echo -e "\033[33mlimit.conf中存在类似配置，跳过\033[0m"
	fi
}

#修改pam参数文件
function change_pam {
	grep pam_limits.so /etc/pam.d/login >& /dev/null
	if [ $? -ne 0 ] ; then
		cat 	>> 	/etc/pam.d/login  <<EOF
#add by kingosoft
session   required   pam_limits.so
EOF
		echo -e "\033[32m配置pam.d/login完成\033[0m"
	else	
		echo -e "\033[33mpam.d/login中存在类似配置，跳过\033[0m"
	fi
}

#修改profile参数文件
function change_profile {
	grep ulimit /etc/profile >& /dev/null
	if [ $? -ne 0 ] ; then
		cat 	>> 	/etc/profile  <<EOF
#add by kingosoft
if [ \$USER = "oracle" ]; then
      if [ \$SHELL = "/bin/ksh" ]; then
           ulimit -p 16384
           ulimit -n 65536
      else
           ulimit -u 16384 -n 65536
      fi
fi
EOF
		echo -e "\033[32m配置/etc/profile完成\033[0m"
	else	
		echo -e "\033[33m/etc/profile中存在类似配置，跳过\033[0m"
	fi
}

#静默安装oracle主程序
function install_oracle {
if [ ! -e /etc/oraInst.loc ]; then
	cat > $basepath/new_inst.rsp <<EOF
oracle.install.responseFileVersion="11.2.0"
oracle.install.option=INSTALL_DB_SWONLY
ORACLE_HOSTNAME=
UNIX_GROUP_NAME=dba
INVENTORY_LOCATION=$oraclebase/oraInventory
SELECTED_LANGUAGES=en
ORACLE_HOME=$oraclehome
ORACLE_BASE=$oraclebase
oracle.install.db.InstallEdition=EE
oracle.install.db.EEOptionsSelection=false
oracle.install.db.optionalComponents=oracle.rdbms.partitioning:11.2.0.4.0,oracle.oraolap:11.2.0.4.0,oracle.rdbms.dm:11.2.0.4.0,oracle.rdbms.dv:11.2.0.4.0,oracle.rdbms.lbac:11.2.0.4.0,oracle.rdbms.rat:11.2.0.4.0
oracle.install.db.DBA_GROUP=dba
oracle.install.db.OPER_GROUP=oinstall
oracle.install.db.CLUSTER_NODES=
oracle.install.db.isRACOneInstall=
oracle.install.db.racOneServiceName=
oracle.install.db.config.starterdb.type=
oracle.install.db.config.starterdb.globalDBName=
oracle.install.db.config.starterdb.SID=
oracle.install.db.config.starterdb.characterSet=
oracle.install.db.config.starterdb.memoryOption=
oracle.install.db.config.starterdb.memoryLimit=
oracle.install.db.config.starterdb.installExampleSchemas=
oracle.install.db.config.starterdb.enableSecuritySettings=
oracle.install.db.config.starterdb.password.ALL=
oracle.install.db.config.starterdb.password.SYS=
oracle.install.db.config.starterdb.password.SYSTEM=
oracle.install.db.config.starterdb.password.SYSMAN=
oracle.install.db.config.starterdb.password.DBSNMP=
oracle.install.db.config.starterdb.control=DB_CONTROL
oracle.install.db.config.starterdb.gridcontrol.gridControlServiceURL=
oracle.install.db.config.starterdb.automatedBackup.enable=
oracle.install.db.config.starterdb.automatedBackup.osuid=
oracle.install.db.config.starterdb.automatedBackup.ospwd=
oracle.install.db.config.starterdb.storageType=
oracle.install.db.config.starterdb.fileSystemStorage.dataLocation=
oracle.install.db.config.starterdb.fileSystemStorage.recoveryLocation=
oracle.install.db.config.asm.diskGroup=
oracle.install.db.config.asm.ASMSNMPPassword=
MYORACLESUPPORT_USERNAME=
MYORACLESUPPORT_PASSWORD=
SECURITY_UPDATES_VIA_MYORACLESUPPORT=
DECLINE_SECURITY_UPDATES=true
PROXY_HOST=
PROXY_PORT=
PROXY_USER=
PROXY_PWD=
PROXY_REALM=
COLLECTOR_SUPPORTHUB_URL=
oracle.installer.autoupdates.option=
oracle.installer.autoupdates.downloadUpdatesLoc=
AUTOUPDATES_MYORACLESUPPORT_USERNAME=
AUTOUPDATES_MYORACLESUPPORT_PASSWORD=
EOF
su  oracle -lc "$basepath/database/runInstaller -ignorePrereq -ignoreSysPrereqs -silent -force -waitforcompletion -responsefile $basepath/new_inst.rsp -showProgress"
$oraclebase/oraInventory/orainstRoot.sh
$oraclehome/root.sh
rm $basepath/new_inst.rsp
else
	echo -e "\033[33m/etc/oraInst.loc存在，跳过\033[0m"
fi
}


function oracleprofile {
su oracle -lc "cat > /home/oracle/.bash_profile <<EOF
# .bash_profile
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi
# User specific environment and startup programs

export ORACLE_SID=$sid
export ORACLE_BASE=$oraclebase
export ORACLE_HOME=$oraclehome
export LD_LIBRARY_PATH=$oraclehome/lib
export NLS_LANG="American_america.$characterset"
export PATH=$oraclehome/bin:\$PATH
umask 022
EOF
"
echo -e "\033[32m配置oracle的bash_profile完成\033[0m"
}

function listener {
cat > $basepath/netca.rsp << EOF
[GENERAL]
RESPONSEFILE_VERSION="11.2"
CREATE_TYPE="CUSTOM"
[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"LISTENER"}
LISTENER_PROTOCOLS={"TCP;1521"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;1521"}	
EOF

#创建监听
su oracle -lc "netca -silent -responseFile $basepath/netca.rsp" 

#关闭监听日志
su oracle -lc "lsnrctl  << EOF
set log_status off
save_config
exit
EOF"
echo -e ""
echo -e "\033[32m配置oracle监听程序完成\033[0m"
rm $basepath/netca.rsp
}

function instdbca {
	
# sga设为总内存的80%再80%
let sga=$mem/1024*64/100
# pga设为总内存的80%再20%
let pga=$mem/1024*16/100

cat >$basepath/dbca.rsp  <<EOF
[GENERAL]
RESPONSEFILE_VERSION = "11.2.0"
OPERATION_TYPE = "createDatabase"
[CREATEDATABASE]
GDBNAME = $sid
SID = $sid
TEMPLATENAME = "General_Purpose.dbc"
SYSPASSWORD = $password
SYSTEMPASSWORD = $password
DBSNMPPASSWORD =$password
STORAGETYPE=FS
ASMSNMP_PASSWORD=$password
CHARACTERSET = $characterset
NATIONALCHARACTERSET= "AL16UTF16"
DATABASETYPE = "MULTIPURPOSE"
AUTOMATICMEMORYMANAGEMENT = "FALSE"
EOF

#创建数据库
su oracle -lc "dbca -initParams java_jit_enabled=false -silent -createDatabase -responseFile $basepath/dbca.rsp"
echo -e "\033[32m创建oracle数据库完成\033[0m"
rm $basepath/dbca.rsp

echo -e "\033[34m正在优化数据库的参数，数据库会自动重启几次，请不要在SQL>状态下进行操作\033[0m"
continue 继续？
#修改数据库的一些参数和模式

su oracle -lc "sqlplus / as sysdba << EOF
   alter system set db_recovery_file_dest_size=500G scope=spfile;
   alter system set sga_target=${sga}M scope=spfile;
   alter system set sga_max_size=${sga}M scope=spfile;
   alter system set pga_aggregate_target=${pga}M scope=spfile;
   alter system set audit_trail=none scope=spfile;
   alter system set audit_sys_operations=false scope=spfile;
   alter system set processes = $process scope=spfile;
   SHUTDOWN IMMEDIATE;
   STARTUP;
   alter profile default limit PASSWORD_LIFE_TIME unlimited;
   exit;
EOF
"
#开启数据库归档模式
if [ $archivemode -eq 1 ];then
su oracle -lc "	sqlplus / as sysdba << EOF
    shutdown immediate;
    startup mount;
    alter database archivelog;
    alter database open;
EOF
"
fi
echo -e "\033[32m数据库优化完成\033[0m"
}

function autostart {
cat > /etc/init.d/oracle <<EOF
#!/bin/bash
# whoami
# root
# chkconfig: 345 51 49
# description: starts the oracle dabase deamons
#
ORACLE_HOME=$orackehome
ORACLE_OWNER=oracle
ORACLE_DESC="Oracle 11g"
ORACLE_LOCK=/var/lock/subsys/oracle11g
case "\$1" in
'start')
echo -n \"Starting \${ORACLE_DESC}:\"
runuser - \$ORACLE_OWNER -c '\$ORACLE_HOME/bin/dbstart \$ORACLE_HOME'

touch \${ORACLE_LOCK}
echo
;;
'stop')
echo -n "shutting down \${ORACLE_DESC}: "
runuser - \$ORACLE_OWNER -c '\$ORACLE_HOME/bin/dbshut \$ORACLE_HOME'
rm -f \${ORACLE_LOCK}
echo
;;
'restart')
echo -n "restarting \${ORACLE_DESC}:"
\$0 stop
\$0 start
echo
;;*)
echo "usage: \$0 { start | stop | restart }"
exit 1
esac
exit 0				
EOF
  
  chmod +x /etc/init.d/oracle
  chkconfig --add oracle
  sed -i 's/:N/:Y/g' /etc/oratab
  echo -e "\033[32m数据库开机自动启动设置完成\033[0m"
	
}

function showall {
	echo -e "----------------------------------------------------------------"
	echo -e "oracle用户设定密码为：$oraclepw"
	echo -e "ORACLE_BASE目录为：$oraclebase"
	echo -e "ORACLE_HOME目录为：$oraclehome"
	echo -e "数据库SID为：$sid"
	echo -e "数据库SYS、SYSTEM用户密码为：$password"
	echo -e "数据库字符集为：$characterset"
	echo -e "数据库用户密码过期时间：永不过期"
	echo -e "数据库审计日志：关闭"
	echo -e "数据库监听日志：关闭"  
	echo -e "数据库内存分配：SGA=${sga}M  PGA=${pga}M"
	echo -e "数据库process设置：$process"
	echo -e "数据库数据文件路径：$oraclebase/oradata/$sid"
	echo -e "数据库快速恢复区路径：$oraclebase/fast_recovery_area/{SID}"
  echo -e "数据库快速恢复区大小限制：500GB"	
  if [ $archivemode -eq 1 ];then
		echo -e "数据库归档模式：开启"
		echo -e "数据库归档文件路径：快速恢复区"
  else
    echo -e "数据库归档模式：关闭"
  fi
	echo -e "数据库启动模式：开机自动启动"
	echo -e "----------------------------------------------------------------"
}

#
###########################主程序开始########################################
#
clear

if [ -L $0 ] ; then 
    BASE_DIR=`dirname $(readlink $0)`
else 
    BASE_DIR=`dirname $0`
fi    
basepath=$(cd $BASE_DIR; pwd)
if [ $basepath = "/root" ];then
	echo -e "\033[31m脚本不能在/root目录下运行，请移到非用户主目录下运行！\033[0m"
  exit 1
fi  

echo -e "\033[36m##########################################################################\033[0m"
echo -e "\033[36m#                Oracle11g文字终端自动安装脚本 版本号V1.0                #\033[0m"
echo -e "\033[36m#                         青果软件 Kingosoft 蔡坚                        #\033[0m"
echo -e "\033[36m##########################################################################\033[0m"

cpu=`cat /proc/cpuinfo |grep "processor"|sort -u|wc -l`
mem=`awk '($1 == "MemTotal:"){print $2}' /proc/meminfo`
os=`cat /etc/redhat-release`
version=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
swap=`free  |grep "Swap" | awk '{print $2}'`


echo -e "\033[34m检查服务器环境是否满足要求\033[0m"
echo -e "操作系统(Centos7):           \033[36m$os\033[0m"
echo -e "逻辑CPU核心数(>=16):         \033[36m$cpu\033[0m"
echo -e "系统总内存(>=33554432KB):    \033[36m$mem\033[0m"
echo -e "系统交换分区(>=8388608KB):   \033[36m$swap\033[0m"
if [ ! $version -eq 7 ];then
	echo -e "\033[31m#只支持Centos7 安装Oracle11.2.0.4，退出#\033[0m"
  exit 1
fi

continue 以上是推荐要求，请尽量满足，继续？

echo -e "\033[34m正在关闭防火墙\033[0m"
systemctl stop firewalld && systemctl disable firewalld
if [ $? -eq 0 ];then
	echo -e "\033[32m防火墙已关闭\033[0m"
else
	echo -e "\033[31m防火墙关闭异常！\033[0m"
	exit -1
fi

echo -e "\033[34m正在关闭Selinux\033[0m"
selinux=`getenforce`
if [ $selinux != "Disabled" ] ;then
	sed -i "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config && setenforce 0
	if [ $? -eq 0 ];then
		echo -e "\033[32mSelinux已关闭\033[0m"
	else
	echo -e "\033[31mSelinux关闭异常！\033[0m"
	exit -1
	fi
else
	echo -e "\033[32mSelinux已关闭\033[0m"
fi



echo -e "\033[34m正在检查服务器可以连接互联网\033[0m"
network
if [ $? -eq 1 ];then
	echo -e "\033[31m网络不畅通，请检查网络设置！\033[0m"
	exit -1
fi
echo -e "\033[32m网络畅通，你可以上网！\033[0m"


echo -e "\033[34m手动检查确保IP地址为静态，非DHCP获取(查阅/etc/sysconfig/network-scripts/ifcfg-***)\033[0m"
continue 检查无误，继续？

echo -e "\033[34m手动检查/etc/hosts文件为主机配置了正确的主机名和IP\033[0m"
cat /etc/hosts
continue 检查无误，继续？

echo -e "\033[34m手动检查磁盘容量符合要求\033[0m"
df -h /
continue 检查无误，继续？

echo -e "\033[34m手动检查oracle安装包1、2已经存在\033[0m"
ls -l $basepath/p133*
continue 检查无误，继续？

#echo -e "\033[34m现在升级操作系统到最新的补丁集\033[0m"
#引入aliyun的Centos7镜像
#curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
#yum makecache
#yum -y update


echo -e "\033[34m设置oracle用户密码:[Kingo123]\033[0m"
read -e  -i "Kingo123" oraclepw

echo -e "\033[34m设置ORACLE_BASE[/u01/app/oracle]\033[0m"
read -e  -i "/u01/app/oracle" oraclebase

echo -e "\033[34m设置ORACLE_HOME[$oraclebase/product/11.2/db_1]\033[0m"
read -e  -i "$oraclebase/product/11.2/db_1" oraclehome
continue 以上设置正确，继续创建用户？

echo -e "\033[34m正在创建用户、组和目录\033[0m"
add_user_dir
continue 继续配置核心文件？

echo -e "\033[34m正在配置sysctl.conf核心文件\033[0m"
change_kernel
continue 继续？

echo -e "\033[34m正在配置limit.conf核心文件\033[0m"
change_limit
continue 继续？

echo -e "\033[34m正在配置pam_login核心文件\033[0m"
change_pam
continue 继续？

echo -e "\033[34m正在配置profile核心文件\033[0m"
change_profile
continue 配置完成，继续在线安装必要的软件包？

echo -e "\033[34m正在在线安装必要的软件包\033[0m"
yum install -y openssl make gcc binutils gcc-c++ compat-libstdc++ elfutils-libelf-devel elfutils-libelf-devel-static ksh libaio libaio-devel numactl-devel sysstat unixODBC \ unixODBC-devel pcre-devel glibc.i686 unzip sudo
continue 安装完成，继续解压oracle安装软件包？

echo -e "\033[34m正在解压oracle软件包\033[0m"
if [ ! -d $basepath/database ] ; then
	unzip $basepath/p13390677_112040_Linux-x86-64_1of7.zip -d $basepath
	unzip $basepath/p13390677_112040_Linux-x86-64_2of7.zip -d $basepath
else
	echo -e "\033[33m目录database已经存在，请手动检查文件夹里面的内容，跳过\033[0m"
fi
continue 接下来正式安装oracle主程序，继续？

echo -e "\033[34m正在安装oracle主程序\033[0m"
 install_oracle
continue 接下来进行数据库的配置，继续？

echo -e "\033[34m设置数据库SID:[oradb]\033[0m"
read -e  -i "oradb" sid
echo -e "\033[34m设置数据库字符集:[ZHS16GBK、AL32UTF8]\033[0m"
read -e  -i "ZHS16GBK" characterset 
echo -e "\033[34m设置数据库SYS、SYSTEM密码:\033[0m"
read -e  -i "Kingo123" password
echo -e "\033[34m设置数据库process连接数:[1500]\033[0m"
read -e  -i "1500" process
echo -e "\033[34m设置数据库是否开启归档模式：\033[0m"
while true;do
  read -s -e  -n1 -p "[1.是 0.否]" archivemode
  case $archivemode in
  1 | 0)
        break;;
  esac
done

continue 接下来正式创建数据库，继续？
echo -e "\033[34m开始创建数据库:\033[0m"

oracleprofile
continue 继续？
listener
continue 继续？
instdbca

continue 接下来设置oracle开机自动启动，继续？
autostart

continue 安装全部结束，显示安装汇总？
showall

if [ $archivemode -eq 1 ];then
	echo -e "\033[31m重要提醒：由于开启了归档模式，请务必使用rman工具定期清理归档日志，否则会造成磁盘空间大量占用。\033[0m"
fi
