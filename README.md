# lemp-centos
Centos 7 - x64.
Lemp via supervisord (php7.2 + nginx + phpfpm)
Make directory in root: /server_data/; 
Create directories for you domains like: /server_data/test1.com; /server_data/test2.com;
Copy and run: ./install.sh;
This shell script generate configs to: /server_data/nginx/test1.com.conf; 
Supervisord conf to: /server_data/supervisord.conf;
This script make secure installation (mariadb5.5 stable), adds include directory for nginx configs to /etc/nginx/conf; install latest php72 + php-fpm + nginx + composer; Mysql root password - root, login - root; 
