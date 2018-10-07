export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
Mem=`free -m | awk '/Mem:/{print $2}'`
Swap=`free -m | awk '/Swap:/{print $2}'`

if [ $Mem -le 640 ]; then
  Mem_level=512M
  Memory_limit=64
  THREAD=1
elif [ $Mem -gt 640 -a $Mem -le 1280 ]; then
  Mem_level=1G
  Memory_limit=128
elif [ $Mem -gt 1280 -a $Mem -le 2500 ]; then
  Mem_level=2G
  Memory_limit=192
elif [ $Mem -gt 2500 -a $Mem -le 3500 ]; then
  Mem_level=3G
  Memory_limit=256
elif [ $Mem -gt 3500 -a $Mem -le 4500 ]; then
  Mem_level=4G
  Memory_limit=320
elif [ $Mem -gt 4500 -a $Mem -le 8000 ]; then
  Mem_level=6G
  Memory_limit=384
elif [ $Mem -gt 8000 ]; then
  Mem_level=8G
  Memory_limit=448
fi

Make-swapfile() {
  dd if=/dev/zero of=/swapfile count=$COUNT bs=1M
  mkswap /swapfile
  swapon /swapfile
  chmod 600 /swapfile
  [ -z "`grep swapfile /etc/fstab`" ] && echo '/swapfile    swap    swap    defaults    0 0' >> /etc/fstab
}

# add swapfile
if [ "$Swap" == '0' ]; then
  if [ $Mem -le 1024 ]; then
    COUNT=1024
    Make-swapfile
  elif [ $Mem -gt 1024 -a $Mem -le 2048 ]; then
    COUNT=2048
    Make-swapfile
  fi
fi

sudo yum update -y
sudo yum -y install epel-release
sudo yum install nginx -y

sudo cat > /etc/yum.repos.d/Maria_Db.repo << EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/5.5/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
sudo yum install MariaDB-server MariaDB-client -y

sudo cat > /etc/my.cnf << EOF
[mysqld]
innodb_buffer_pool_size     = 512M
innodb_file_per_table       = 1
innodb_flush_method         = O_DIRECT
max_connections             = 132
query_cache_size            = 0
EOF
sudo sed -i "s@max_connections.*@max_connections = $((${Mem}/3))@" /etc/my.cnf
 sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
 sudo yum install yum-utils -y
 sudo yum-config-manager --enable remi-php72 -y
 sudo yum update -y
 sudo yum install php72 php72-php-fpm php72-php-gd php72-php-json php72-php-mbstring php72-php-mysqlnd php72-php-xml php72-php-xmlrpc php72-php-opcache -y
 sudo sed -ie 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/opt/remi/php72/php-fpm.d/www.conf
 sudo sed -ie 's/;user = nginx/user = apache/g' /etc/opt/remi/php72/php-fpm.d/www.conf
 sudo sed -ie 's/;group = nginx/group = apache/g' /etc/opt/remi/php72/php-fpm.d/www.conf
 sed '/# for more information./a\ninclude /server_data/nginx/*.conf;' /etc/nginx/nginx.conf
 for domain in /server_data/*; do
    if [[ -d $domain ]]; then
     sudo mkdir /server_data/nginx/; 
     if [ "$domain" != "nginx" ]; then
        sudo touch  /server_data/nginx/${domain##*/}.conf 
        sudo cat > /server_data/nginx/${domain##*/}.conf << EOF
            server {
              server_name ${domain##*/} *.${domain##*/};
              index index.html index.htm index.php;
              root /server_data/${domain##*/}/;
              location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|mp4|ico)$ {
                    expires 30d;
                    access_log off;
              }
              location ~ .*\.(js|css)?$ {
                    expires 7d;
                    access_log off;
              }   
              location ~ /\.ht {
                    deny all;
              }
              location ~ \.php$ { 
                  try_files $uri =404; 
                  include /etc/nginx/fastcgi.conf;
                  fastcgi_pass 127.0.0.1:9000;
                  fastcgi_index index.php;
              }
          }
EOF
        fi;
    fi;
done;
 rm /server_data/nginx/nginx.conf;
 yum -y install expect
MYSQL_ROOT_PASSWORD="root"
SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect "Enter current password for root (enter for none):"
send "$MYSQL\r"

expect "Set root password?"
send "y\r"

expect "New password:"
send "$MYSQL_ROOT_PASSWORD\r"

expect "Re-enter new password:"
send "$MYSQL_ROOT_PASSWORD\r"

expect "Remove anonymous users?"
send "y\r"

expect "Disallow root login remotely?"
send "y\r"

expect "Remove test database and access to it?"
send "y\r"

expect "Reload privilege tables now?"
send "y\r"
expect eof
")

echo "$SECURE_MYSQL"
 yum -y remove expect
 yum -y install python-setuptools python-pip
 easy_install supervisor
 echo_supervisord_conf  > /server_data/supervisor.conf
 sudo cat > /usr/lib/systemd/system/supervisord.service << EOF
[Unit]                                                              
 Description=supervisord - Supervisor process control system for UNIX
 Documentation=http://supervisord.org                                
 After=network.target                                                
[Service]
 User=root                                                         
 Type=forking                                                        
 ExecStart=/usr/bin/supervisord -c /server_data/supervisor.conf             
 ExecReload=/usr/bin/supervisorctl reload -c /server_data/supervisor.conf                                      
 ExecStop=/usr/bin/supervisorctl shutdown                            
[Install]                                                           
 WantedBy=multi-user.target
EOF
 
sudo cat >> /server_data/supervisor.conf << EOF


[program:mysql]
command = /usr/sbin/mysqld  --user root
priority=999
autostart=true
autorestart=true

[program:php-fpm]
command = /opt/remi/php72/root/usr/sbin/php-fpm
autostart=true
autorestart=true
priority=5
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=/usr/sbin/nginx -g "daemon off; error_log /dev/stderr info;"
autostart=true
autorestart=true
priority=10
stdout_events_enabled=true
stderr_events_enabled=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF
 sudo systemctl daemon-reload
 sudo systemctl enable supervisord
 sudo systemctl restart supervisord
 sudo yum install composer -y
