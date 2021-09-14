#!/bin/bash

#This script only works under below conditions
# 1. Docker is installed

# specify container name
CONTAINER_NAME=jay

function usage(){
    cat <<_EOT_
launch-docker.sh

Usage:
    $0 Option

Description:
    start and stop $CONTAINER_NAME on container

Options:
    start      start $CONTAINER_NAME on container
    stop       stop $CONTAINER_NAME
    status     show $CONTAINER_NAME's condition
    restart    stop and restart container
    help       show this usage
    [command]  execute [command] in container
_EOT_
}

function main(){
    if ! user_belongs_dockergroup; then
        echo "You have to be member of docker group"
        exit 1
    fi

    cd "$(dirname "$0")"
    cd ../

    case "$1" in
        start)
            start
            ;;
        stop)
            stop
            ;;
        status)
            status
            ;;
        restart)
            restart
            ;;
        help)
            usage
            ;;
        *)
            start_with_command "$1"
            ;;
    esac
    return 0
}

function user_belongs_dockergroup(){
    if [ $(groups | grep -c -e docker -e root) = 0 ]; then
        return 1
    fi
    return 0
}

function start(){
    if container_is_running $CONTAINER_NAME; then
        echo "$CONTAINER_NAME has already runnning"
    else
        echo -n "try to start $CONTAINER_NAME..."
        docker run -d --name $CONTAINER_NAME -p 3000:3000 \
            -v $PWD/db:/home/jay/db \
            -v $PWD/config:/home/jay/config \
            --restart=always \
            $CONTAINER_NAME > /dev/null && \
            echo "done." || \
            exit 1
    fi
}

function start_with_command(){
    if container_is_running $CONTAINER_NAME; then
        echo "$CONTAINER_NAME has already runnning"
    else
        docker run -it --name $CONTAINER_NAME -p 3000:3000 \
            -v $PWD/db:/home/jay/db \
            -v $PWD/config:/home/jay/config \
            $CONTAINER_NAME  "$1"
    fi
}

function stop(){
    if container_is_running $CONTAINER_NAME; then
        echo -n "try to stop $CONTAINER_NAME..."
        docker stop $CONTAINER_NAME > /dev/null 2>&1
        docker rm $CONTAINER_NAME > /dev/null && \
            echo "done." || \
            exit 1
    else
        echo "$CONTAINER_NAME is not running"
    fi
}

function status(){
    if container_is_running $CONTAINER_NAME; then
        echo "running"
    else
        echo "stop"
    fi
}

function restart(){
    if container_is_running $CONTAINER_NAME; then
        stop
        start
    else
        echo "$CONTAINER_NAME is not runnning"
        start
    fi
}

function container_is_running(){
    if [ $(docker ps -a --format "table {{.Names}}" |grep -cx "$1") = 0 ]; then
        return 1
    else
        return 0
    fi
}

main "$@"
