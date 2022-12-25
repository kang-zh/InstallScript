#！/bin/bash
################################################################################
# 在Ubuntu 16.04、18.04 和 20.04 上安装 Odoo 的脚本（也可用于其他版本）。
# 作者: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# 这个脚本将在你的 Ubuntu 16.04 服务器上安装 doo。它可以在一台Ubuntu上安装多个Odoo实例
# 在一个Ubuntu中，因为有不同的xmlrpc_port
#-------------------------------------------------------------------------------
# 创建一个新文件。
# sudo nano odoo-install.sh
# 把这些内容放在里面，然后让文件可执行。
# sudo chmod +x odoo-install.sh
# 执行该脚本以安装 Odoo 。
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
# 这个 Odoo 实例运行的默认端口（ 如果你在终端使用命令 -c ）。
# 如果你想安装它，就设置为 true，如果你不需要它或已经安装了它，就设置为 false 。
INSTALL_WKHTMLTOPDF="True"
# 设置默认的 Odoo 端口（例如，你仍然必须使用 -c /etc/odoo-server.conf 来使用这个端口）。
OE_PORT="8069"
# 选择你要安装的 Odoo 版本。例如：16.0、15.0、14.0 或 saas-22。当使用'master'时，主版本将被安装。
# 重要的是! 这个脚本包含Odoo 16.0 特别需要的额外库。
OE_VERSION="16.0"
# 如果你想安装 Odoo 企业版，将此设置为 True!
IS_ENTERPRISE="False"
# 如果你想安装Nginx，将此设置为 True!
INSTALL_NGINX="True"
# 设置超级管理员密码 - 如果 GENERATE_RANDOM_PASSWORD 设置为 "True"，我们将自动生成一个随机密码，否则我们使用这个密码。
OE_SUPERADMIN="admin"
# 设置为 "True" 以生成随机密码，"False" 则使用 OE_SUPERADMIN 中的变量。
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
# 设置网站名称
WEBSITE_NAME="erp.fzopt.com"
# 设置默认的 Odoo longpolling 端口（例如你仍然需要使用 -c /etc/odoo-server.conf 来使用这个端口）。
LONGPOLLING_PORT="8072"
# 设置为 "True " 表示安装 certbot 并启用 ssl，"False " 表示使用 http
ENABLE_SSL="True"
# 提供电子邮件来注册 ssl 证书
ADMIN_EMAIL="qa@fzopt.com"
##
###  WKHTMLTOPDF 下载链接
## === Ubuntu Trusty x64 & x32 === (对于其他发行版，请替换这两个链接。 以便安装正确版本的 wkhtmltopdf，危险提示请参考
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/16.0/administration/install.html

WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_amd64.deb"
WKHTMLTOX_X32="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_i386.deb"
#--------------------------------------------------
#  更新服务
#--------------------------------------------------
echo -e "\n---- 更新服务 ----"
# 宇宙包适用于 Ubuntu 18.x
sudo add-apt-repository universe
# libpng12-0 依赖 for wkhtmltopdf
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install libpq-dev

#--------------------------------------------------
# 安装 PostgreSQL 服务
#--------------------------------------------------
echo -e "\n---- 安装 PostgreSQL 服务 ----"
sudo apt-get install postgresql -y

echo -e "\n---- 创建 ODOO PostgreSQL 用户  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
#   安装依赖
#--------------------------------------------------
echo -e "\n--- 安装 Python 3 + pip3 --"
sudo apt-get install python3 python3-pip
sudo apt-get install git python3-cffi build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi -y

echo -e "\n---- Install python packages/requirements ----"
sudo -H pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- 安装 nodeJS NPM 和 rtlcss 以支持 LTR ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# 如果需要的话，安装 Wkhtmltopdf
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- 安装 wkhtml 并将快捷方式放在 ODOO 13 的正确位置上 ----"
  #从 x64 和 x32 版本中选取正确的一个:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "由于用户的选择, Wkhtmltopdf 没有被安装!"
fi

echo -e "\n---- 创建 ODOO 系统用户 ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#该用户也应该被添加到 sudo'ers 组。
sudo adduser $OE_USER sudo

echo -e "\n---- 创建日志目录 ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# 安装 ODOO
#--------------------------------------------------
echo -e "\n==== 安装 ODOO 服务 ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo企业版安装!
    sudo pip3 install psycopg2-binary pdfminer.six
    echo -e "\n--- 为节点创建软连接"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------警告------------------------------"
        echo "您的Github认证失败了! 请再试一次。"
        printf "为了克隆和安装 Odoo 企业版, 你需要成为 Odoo 的正式合作伙伴, 并且你需要访问\nhttp://github.com/odoo/enterprise.\n"
        echo "提示: 按ctrl+c来停止这个脚本"
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- 在 $OE_HOME/enterprise/addons 添加了企业代码 ----"
    echo -e "\n---- 安装企业专用库 ----"
    sudo -H pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- 创建自定义模块目录 ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- 设置主文件夹的权限 ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* 创建服务器配置文件"


sudo touch /etc/${OE_CONFIG}.conf
echo -e "* 创建服务器配置文件"
sudo su root -c "printf '[options] \n; 这是允许数据库操作的密码:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* 随机生成管密码"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
if [ $OE_VERSION > "11.0" ];then
    sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* 创建启动文件"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# 将 ODOO 添加为一个 deamon（启动脚本）。
#--------------------------------------------------

echo -e "* 创建启动文件"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### 开始 INIT 信息
# 提供: $OE_CONFIG
# 要求-开始: \$remote_fs \$syslog
# 要求-停止: \$remote_fs \$syslog
# 应该-启动: \$network
# 应该-停止: \$network
# 默认-启动: 2 3 4 5
# 默认-停止: 0 1 6
# 简要说明: 企业商务应用
# 描述: ODOO 商务应用
### 结束 INIT 信息
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
# 指定用户名 (Default: odoo).
USER=$OE_USER
# 指定一个替代的配置文件 (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/${OE_CONFIG}.conf"
# pidfile
PIDFILE=/var/run/\${NAME}.pid
# 传递给守护进程的附加选项。
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}
case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* 安全启动文件"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "* 在启动时启动 ODOO "
sudo update-rc.d $OE_CONFIG defaults

#--------------------------------------------------
# 如果需要的话，安装 Nginx
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n---- 安装并设置 Nginx ----"
  sudo apt install nginx -y
  cat <<EOF > ~/odoo
server {
  listen 80;

  # 设置好域名后，再设置适当的服务器名称
  server_name $WEBSITE_NAME;

  # 为 odoo 代理模式添加头文件
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  #   odoo    日志文件
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log       /var/log/nginx/$OE_USER-error.log;

  #   增加代理缓冲区的大小
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   如果后端死了，强制超时
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  types {
    text/less less;
    text/scss scss;
  }

  #   启用数据压缩
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
    proxy_pass    http://127.0.0.1:$OE_PORT;
    # by default, do not forward anything
    proxy_redirect off;
  }

  location /longpolling {
    proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }

  location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
    expires 2d;
    proxy_pass http://127.0.0.1:$OE_PORT;
    add_header Cache-Control "public, no-transform";
  }

  # 在内存中缓存一些静态数据, 持续60分钟.
  location ~ /[a-zA-Z0-9_-]*/static/ {
    proxy_cache_valid 200 302 60m;
    proxy_cache_valid 404      1m;
    proxy_buffering    on;
    expires 864000;
    proxy_pass    http://127.0.0.1:$OE_PORT;
  }
}
EOF

  sudo mv ~/odoo /etc/nginx/sites-available/$WEBSITE_NAME
  sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
  sudo rm /etc/nginx/sites-enabled/default
  sudo service nginx reload
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "完成了! Nginx 服务器已经启动并运行. 配置可在以下地址找到 /etc/nginx/sites-available/$WEBSITE_NAME"
else
  echo "由于用户的选择,Nginx没有被安装!"
fi

#--------------------------------------------------
# 使用 certbot 启用 ssl
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ]  && [ $WEBSITE_NAME != "_" ];then
  sudo add-apt-repository ppa:certbot/certbot -y && sudo apt-get update -y
  sudo apt-get install python3-certbot-nginx -y
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo service nginx reload
  echo "SSL/HTTPS 已启用!"
else
  echo "由于用户的选择或错误的配置, SSL/HTTPS 没有被启用。"
fi

echo -e "* 启动 Odoo 服务"
sudo su root -c "/etc/init.d/$OE_CONFIG start"
echo "-----------------------------------------------------------"
echo "完成了! Odoo 服务器已经启动并运行.规范:"
echo "端口: $OE_PORT"
echo "用户服务: $OE_USER"
echo "配置文件的位置: /etc/${OE_CONFIG}.conf"
echo "日志文件位置: /var/log/$OE_USER"
echo "PostgreSQL 用户: $OE_USER"
echo "代码位置: $OE_USER"
echo "Addons 文件夹: $OE_USER/$OE_CONFIG/addons/"
echo "密码 superadmin (数据库).: $OE_SUPERADMIN"
echo "启动 Odoo 服务: sudo service $OE_CONFIG start"
echo "停止 Odoo 服务: sudo service $OE_CONFIG stop"
echo "重启 Odoo 服务: sudo service $OE_CONFIG restart"
if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx 配置文件: /etc/nginx/sites-available/$WEBSITE_NAME"
fi
echo "-----------------------------------------------------------"
