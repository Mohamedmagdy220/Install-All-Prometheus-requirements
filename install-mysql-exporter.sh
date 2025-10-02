
#!/bin/bash

################################################################################
# Author : Awais Khan                                                          #
# Use this script as a root user.                                              #
# This script is used to create a MySQL exporter service for prometheus        #
# the service will use port 9104 by default                                    #
################################################################################

export DEBIAN_FRONTEND=noninteractive
apt update
which mysql
if [ $? == 1 ];then

printf "\n      Please Install Mysql Server before installing the Exporter . \n\n"

else
printf "\n Installed : \n\n"
which curl wget tar


if [ $? == 1 ];then

printf "\n  Make sure that you have these dependencies installed
    curl , wget , tar \n\n
"

else
curl -s https://api.github.com/repos/prometheus/mysqld_exporter/releases/latest   | grep browser_download_url   | grep linux-amd64 | cut -d '"' -f 4   | wget -i -
printf "\n\n ------------------------ Extracting Files ------------------------\n"
tar xvf mysqld_exporter*.tar.gz
mv  mysqld_exporter-*.linux-amd64/mysqld_exporter /usr/local/bin/
chmod +x /usr/local/bin/mysqld_exporter


groupadd --system mysql_exporter
useradd -s /sbin/nologin --system -g mysql_exporter mysql_exporter
printf "\n\n ------------------------ Please Provide the following Things ------------------------\n\n"

cat << EOF > /tmp/commands.sql
   CREATE USER 'mysqld_exporter'@'localhost' IDENTIFIED BY 'prometheus' WITH MAX_USER_CONNECTIONS 2;
   GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'mysqld_exporter'@'localhost';
   FLUSH PRIVILEGES;
   EXIT
EOF

read -p "Enter Username of Your MySQL database > " Mysql_username
read -p "Enter Password of Your MySQL database > " Mysql_password

mysql -u $Mysql_username --password=$Mysql_password < /tmp/commands.sql

rm -rf /tmp/commands.sql

cat << EOF > /etc/.mysqld_exporter.cnf
[client]
user=mysqld_exporter
password=prometheus
host=localhost
EOF
chown root:mysql_exporter /etc/.mysqld_exporter.cnf


cat << EOF > /etc/systemd/system/mysql_exporter.service

[Unit]
 Description=Prometheus MySQL Exporter
 After=network.target
 User=mysql_exporter
 Group=mysql_exporter

 [Service]
 Type=simple
 Restart=always
 ExecStart=/usr/local/bin/mysqld_exporter \
 --config.my-cnf /etc/.mysqld_exporter.cnf \
 --collect.global_status \
 --collect.info_schema.innodb_metrics \
 --collect.auto_increment.columns \
 --collect.info_schema.processlist \
 --collect.binlog_size \
 --collect.info_schema.tablestats \
 --collect.global_variables \
 --collect.info_schema.query_response_time \
 --collect.info_schema.userstats \
 --collect.info_schema.tables \
 --collect.perf_schema.tablelocks \
 --collect.perf_schema.file_events \
 --collect.perf_schema.eventswaits \
 --collect.perf_schema.indexiowaits \
 --collect.perf_schema.tableiowaits \
 --collect.slave_status \
 --web.listen-address=0.0.0.0:9104

 [Install]
 WantedBy=multi-user.target


EOF

systemctl daemon-reload
systemctl enable mysql_exporter
systemctl start mysql_exporter

fi



fi


