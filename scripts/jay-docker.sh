#!/bin/bash

#This script only works under below conditions
# 1. Docker is installed

# default value
DEFAULT_ATTACH_OPTION=it # {i|t|it|d}
DEFAULT_PORT=3000 # host port which jay server binds
DEFAULT_COMMAND="" # command which execute in container
                   # using default entrypoint of image, specify ""

# constant value
IMAGE_NAME=jay
CONTAINER_NAME=jay
SCRIPT_NAME=jay-docker.sh


function print_usage(){
    cat <<_EOT_
launch-docker.sh

Usage:
    $SCRIPT_NAME COMMAND

Description:
    start and stop $IMAGE_NAME on container

Commands:
    start    start $IMAGE_NAME server on container
             for more details, run '$SCRIPT_NAME start -h'
    stop     stop $IMAGE_NAME server
    status   show conditions of $IMAGE_NAME container
    restart  restart $IMAGE_NAME container
    help     show this usage
_EOT_
}

function print_start_usage(){
    cat <<_EOT_
Usage:
    $SCRIPT_NAME start [OPTION] [COMMAND]

Description:
    run $IMAGE_NAME server on docker container
    if cpmmand is specified, run COMMAND instead of dafault entrypoint

Options:
    -d         dettach: input and output is discarded
    -p number  port: bind 'number' port (default 3000)
    -h         help: show this usage
_EOT_
}

function main(){
    if ! user_belongs_dockergroup; then
        echo "$(whoami) must belong 'docker' group"
        exit 1
    fi

    cd "$(dirname "$0")"
    cd ../

    case "$1" in
        start)
            shift
            start $@
            ;;
        stop)
            stop
            ;;
        status)
            status
            ;;
        restart)
            shift
            restart $@
            ;;
        help)
            print_usage
            ;;
        "")
            print_usage
            ;;
        *)
            echo "Invalid option: '$1'"
            exit 1
            ;;
    esac
    return 0
}

function start(){
    PORT=$DEFAULT_PORT
    COMMAND=$DEFAULT_COMMAND
    ATTACH_OPTION=$DEFAULT_ATTACH_OPTION

    if container_is_running $CONTAINER_NAME; then
        echo "$CONTAINER_NAME is already runnning"
        exit 1
    fi

    if ! image_exists; then
        echo "docker image not found: $IMAGE_NAME"
        exit 1
    fi

    if ! istty; then
        ATTACH_OPTION=i
    fi

    if port_is_used; then
        echo "Port $PORT is used"
        exit 1
    fi

    set_start_options $@

    echo "starting $CONTAINER_NAME"
    docker run \
        -$ATTACH_OPTION \
        -p $PORT:3000 \
        -v $PWD/db:/home/jay/db \
        -v $PWD/config:/home/jay/config \
        --rm \
        --name $CONTAINER_NAME \
        $IMAGE_NAME $COMMAND
}

function set_start_options(){
    while getopts dhop: OPT; do
        case $OPT in
            d)
                ATTACH_OPTION=d
                ;;
            h)
                print_start_usage
                exit 0
                ;;
            p)
                PORT=$OPTARG
                ;;
            *)
                exit 1
                ;;
        esac
    done
    COMMAND=${@:$OPTIND}
}

function stop(){
    if ! container_is_running; then
        echo "$CONTAINER_NAME is not running"
        exit 1
    fi

    echo -n "try to stop $CONTAINER_NAME..."
    docker stop $CONTAINER_NAME > /dev/null && \
        echo "done."
}

function status(){
    if container_is_running; then
        echo "$CONTAINER_NAME is running"
    else
        echo "$CONTAINER_NAME is not running"
    fi
}

function restart(){
    if container_is_running; then
        stop
        start $@
    else
        echo "$CONTAINER_NAME is not runnning"
        start $@
    fi
}

function user_belongs_dockergroup(){
    if [ $(groups | grep -c -e docker -e root) = 0 ]; then
        return 1
    else
        return 0
    fi
}

function container_is_running(){
    if [ $(docker ps -a --format "table {{.Names}}" |grep -cx "$CONTAINER_NAME") = 0 ]; then
        return 1
    else
        return 0
    fi
}

function image_exists(){
    if [ $(docker images $IMAGE_NAME | wc -l) = 1 ]; then
        return 1
    else
        return 0
    fi
}

function istty(){
    if [ "$(tty)" = "not a tty" ]; then
        return 1
    else
        return 0
    fi
}

function port_is_used(){
    if [ $(ss -antu | grep -c $PORT) != 0 ]; then
        return 0
    else
        return 1
    fi
}

main "$@"
