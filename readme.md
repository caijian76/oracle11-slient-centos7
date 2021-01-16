# ORACLE11G 在 CentOS7 下的文本界面自动安装

## 1.什么是oracle11-centos7

只需要下载一个脚本程序，下载地址为 http://www.kingosoft.com:8000/f/4ed0281ff0044c5db8c2  ，配合Oracle11g的2个安装程序包，即可在没有图形化界面支持的环境下，轻松一键安装配置优化的数据库。

## 2.环境要求

1. 最小化安装的Centos7
2. 能接入互联网
3. 配置了固定IP
4. 设置了主机名，并在/etc/hosts里面正确的绑定了IP
5. 足够的硬盘空间（生产环境下推荐>500GB，测试环境>20GB）

## 3.安装步骤

1. SSH客户端，登录服务器
2. 创建/oracle目录
3. 把oracle11-centos7脚本文件，和oracle11.2.0.4的2个安装文件（p13390677_112040_Linux-x86-64_1of7.zip，p13390677_112040_Linux-x86-64_2of7.zip）上传到/oracle目录下
4. `chmod +x oracle11-centos7` 修改脚本的执行权限
5. 运行 `/oracle/oracle11-centos7` ，开始轻松愉快的根据页面指引，完成安装吧。

## 4.安装特色

1. 全文本界面下进行安装，避免了服务器图形化支持的问题。
2. 从全新的操作系统到安装完成，几乎一键完成。
3. 根据经验，定制了一些优化。
   1. 根据服务器的内存量，自动计算oracle的内存分配。
   2. 设置oracle数据库的密码为永不过期。
   3. 可选是否开启归档模式。
   4. 可定义数据库字符集。
   5. 可自定义数据库process参数。
   6. 关闭了审计日志。
   7. 关闭了监听日志。
   8. 一键设置开机Oracle自动启动。
4. 安装完成，提供信息汇总清单，方便记录。
5. 统一安装标准，方便后期维护。

## 5.注意事项

1. 目前只在Centos7环境下安装Oracle11.2.0.4进行了测试，别的环境请不要使用。
2. 只支持Oracle单机部署，不支持RAC构架。
3. 安装脚本不要上传到/root、/home/*** 等用户主目录下。会导致运行时的权限问题。
4. 开启了归档模式后，必须要另外使用RMAN工具，定期处理归档日志，否则归档会占用大量硬盘空间
5. 欢迎大家进行测试，如有问题，可联系我。（蔡坚 15307310420）















