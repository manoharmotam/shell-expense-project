#!/bin/bash


RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NOCOLOR='\e[0m'
LOGS_FOLDER="/var/log/roboshop"
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user $LOGS_FOLDER
sudo chmod -R 755 $LOGS_FOLDER
LOGS_FILE="$LOGS_FOLDER/$0.log"
TIMESTAMP=$(date '+%Y-%m-%d %T')
SCRIPTDIR=$PWD

#user validation
if [ $(id -u) -ne 0 ]; then
    echo -e "$RED Please run this script as Root User $NOCOLOR" | tee -a "$LOGS_FILE"
    exit 1
fi


VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$TIMESTAMP $RED [ERROR] $NOCOLOR -- $2 Failed" | tee -a "$LOGS_FILE"
        exit 1
    else
        echo -e "$TIMESTAMP $GREEN [SUCCESS] $NOCOLOR -- $2 Success" | tee -a "$LOGS_FILE"
    fi
}

dnf module disable nginx -y &>> "$LOGS_FILE"
dnf module enable nginx:1.24 -y &>> "$LOGS_FILE"
dnf install nginx -y &>> "$LOGS_FILE"
VALIDATE $? "Enabling and installing the Nginx 1.24"

rm -f /etc/nginx/nginx.conf
VALIDATE $? "Removing existing Default nginx configuration"

cp "$SCRIPTDIR"/configs/loadbalancer.conf /etc/nginx/nginx.conf
VALIDATE $? "Updating the nginx config for services routing"

systemctl daemon-reload
systemctl enable nginx &>> "$LOGS_FILE"
systemctl start nginx
VALIDATE $? "Enabling and starting nginx"