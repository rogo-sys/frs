#!/bin/bash

if [ -z "$ZABBIX_TOKEN" ]; then
    echo -n "Enter the Zabbix token: "
    read -s token
    echo
    export ZABBIX_TOKEN="$token"
    echo "Token set for this session"
else
    echo "Token already set"
fi