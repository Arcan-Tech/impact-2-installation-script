#!/bin/bash

#images() {
#    docker images --format '{{.Repository}}:{{.Tag}}'
#}
#read -p "Uninstall Impact Analysis and delete all results? [y/n]: " CONFIRM
#if [[ "$CONFIRM" == "y" ]]; then
#    docker compose down -v
#    docker rmi --force $(images | grep 'ghcr.io/arcan-tech/impact-*:latest')
#    docker rmi --force $(images | grep 'nats')
#    docker rmi --force $(images | grep 'postgres')
#    docker rmi --force $(images | grep 'orientdb')
#    docker rmi --force $(images | grep 'watchtower')
#fi
