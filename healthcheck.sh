#!/bin/bash

url=$(grep "^webServiceUrl" $PULSAR_HOME/conf/client.conf | cut -d '=' -f 2)
pulsar_answer=$(curl -I ${url}admin/v2/brokers/healthcheck -s -o /dev/null -w "%{http_code}")
if [[ $pulsar_answer -eq 200 ]]; then
    exit 0
fi
exit 1
