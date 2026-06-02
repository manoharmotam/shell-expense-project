#!/bin/bash

PROJECT_NAME="expense"
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NOCOLOR='\e[0m'
AMI_ID="ami-0220d79f3f480ecf5"
INSTANCE_TYPE="t3.micro"
DOMAIN_NAME="mrmotam.online"
ZONEID="Z00263282318BT9FBW1XK"

if [ $# -lt 1 ]; then
    echo -e "$RED No Arguments provided. Provide the name to create an instance. $NOCOLOR"
    echo -e "USAGE:: $0 <instance-name>"
    exit 1
fi

get_instance_id(){
    NAME=$1
    aws --no-cli-pager ec2 describe-instances --filters "Name=tag:Name,Values=$PROJECT_NAME-$NAME" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text
}

for instance in "$@"
do
    INSTANCE_ID=$(get_instance_id "$instance")
    if [ "$INSTANCE_ID" == "None" ]; then
        INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" \
            --instance-type "$INSTANCE_TYPE" \
            --security-groups "$PROJECT_NAME-$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PROJECT_NAME-$instance}]" \
            --query "Instances[*].InstanceId" \
            --output text)
        aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
        echo -e "$GREEN $INSTANCE_ID: $instance --- created $NOCOLOR"
    else
        echo -e "$YELLOW $INSTANCE_ID: $instance is already available in the console in running state $NOCOLOR"
    fi

    #Getting public and private IPs

    if [ "$instance" == "loadbalancer" ]; then
        IP=$(aws --no-cli-pager ec2 describe-instances \
                --instance-ids "$INSTANCE_ID" \
                --query "Reservations[*].Instances[*].PublicIpAddress" \
                --output text)
        R53_RECORD="$DOMAIN_NAME"
    else
        IP=$(aws --no-cli-pager ec2 describe-instances \
                --instance-ids "$INSTANCE_ID" \
                --query "Reservations[*].Instances[*].PrivateIpAddress" \
                --output text)
        R53_RECORD="$instance.$DOMAIN_NAME"
    fi

    #updating the R53 records.

    aws  --no-cli-pager route53 change-resource-record-sets --hosted-zone-id $ZONEID \
        --change-batch '
            {
                "Comment": "Creating an A record for '$R53_RECORD' with IP '$IP'",
                "Changes": [
                        {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": "'$R53_RECORD'",
                            "Type": "A",
                            "TTL": 1,
                            "ResourceRecords": [{ "Value": "'$IP'" }]
                        }
                    }
                ]
            }
        '
    echo -e "$GREEN Updated the R53 Record for $instance $NOCOLOR "
done