#!/bin/bash

#variables
NS=cortex
KEY_FILE=key.json
SECRET=gcp-sa
#gcp bucks name
GCP_Blocks_BucketName=cortex-blocks-dev
GCP_Ruler_BucketName=cortex-alert-rules-dev
GCP_Alert_BucketName=cortex-alert-rules-dev

#prometheus_users_secrets in base64 value (openuser:openuser)
prometheus_users=b3BlbnVzZXI=
prometheus_password=b3BlbnVzZXI=

#Create a nginx -user 
declare -A keyValuePairs
# Add key-value pairs to the associative array
#reference link (GENERATE FROM THIS LINK ))https://wtools.io/generate-htpasswd-online
keyValuePairs["openuser"]="\$apr1\$zkm0igj2\$pBwzG/vWJag/CHdpbI0tc."

