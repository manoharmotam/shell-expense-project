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
    echo -e "$RED Please run this script as Root User $NOCOLOR" | tee -a $LOGS_FILE
    exit 1
fi


VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$TIMESTAMP $RED [ERROR] $NOCOLOR -- $2 Failed" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$TIMESTAMP $GREEN [SUCCESS] $NOCOLOR -- $2 Success" | tee -a $LOGS_FILE
    fi
}

dnf module disable nodejs -y &>> $LOGS_FILE
dnf module enable nodejs:20 -y &>> $LOGS_FILE
dnf install nodejs -y &>> $LOGS_FILE
VALIDATE $? "Enabling and installing the NodeJS 20"

id expense &>> $LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" expense
    VALIDATE $? "Creating the user for the application"
else
    echo "User roboshop already exists"
fi

rm -rf /app
VALIDATE $? "Removing existing code"

mkdir -p /app 
curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-90s/expense-documentation/refs/heads/main/artifacts/expense-backend-v3.tar.gz &>> $LOGS_FILE
cd /app 
tar -xzf /tmp/backend.tar.gz &>> $LOGS_FILE
npm install  &>> $LOGS_FILE
VALIDATE $? "Downloading the dependencies and packaging the App"

cp "$SCRIPTDIR"/configs/backend.service /etc/systemd/system/
VALIDATE $? "Creating the Backend service for the App"

dnf install mysql -y &>> $LOGS_FILE
VALIDATE $? "Installing the MySQL Client"

mysql -h mysqldb.mrmotam.online -u root -pExpenseApp@1 < /app/schema/backend.sql
VALIDATE $? "Loading the database schema"

systemctl daemon-reload
systemctl enable backend &>> $LOGS_FILE
systemctl start backend
VALIDATE $? "Enabling and starting the cataloge services"