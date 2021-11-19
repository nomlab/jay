#!/bin/bash

# This scripts is for setting up jay image
# * Create jay image
# * Create master.key
# * Migrate database for production

function main() {
    cd $(dirname $0)
    cd ../

    if [ "$1" = "" ]; then
        usage
        exit 1
    fi

    if ! user_exists $1; then
        echo "Specified user does not exist"
        exit 1
    fi

    if ! docker_is_available; then
        echo "docker command not found"
        echo "Install docker or chack PATH"
        exit 1
    fi

    if ! user_belongs_dockergroup; then
        echo "Cannot use docker without sudo"
        echo "Belong docker group"
        exit 1
    fi

    if jay_image_exists; then
        echo "Already 'jay' image exists"
        echo -n "Are you sure to overwrite image [yN]: "
        read RES
        if [ $RES != y ] && [ $RES != Y ]; then
            echo abort
            exit 1
        fi
    fi

    echo "Create jay image"
    UID_SH=$(id -u $1)
    docker build -t jay -f ./Dockerfile_production --build-arg UID=$UID_SH . || \
        exit 1

    echo "Setup secret key and database"
    PORT=3000
    while [ $(ss -antu | grep -c :$PORT) != 0 ]; do
        PORT=$(expr $PORT + 1)
    done
    ./scripts/jay-docker.sh start -p $PORT ./scripts/docker/docker-setup.sh || \
        exit 1

    echo "done"
}

function usage() {
    cat <<_EOT_
usage: setup-docker.sh <UserName>
       <UserName> is the name of user that runs jay container.
_EOT_
}

function docker_is_available(){
    if ! which docker > /dev/null; then
        return 1
    else
        return 0
    fi
}

function user_exists() {
    if id -u $1 > /dev/null; then
        return 0
    else
        return 1
    fi
}

function user_belongs_dockergroup(){
    if [ $(groups | grep -c -e docker -e root) = 0 ]; then
        return 1
    else
        return 0
    fi
}

function jay_image_exists(){
    if [ $(docker images jay | wc -l) = 1 ]; then
        return 1
    else
        return 0
    fi
}

main $1
