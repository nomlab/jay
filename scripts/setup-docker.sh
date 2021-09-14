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

    if ! (user_exists $1); then
        echo "Specified user does not exist"
        exit 1
    fi

    echo "Create jay image"
    UID_SH=$(id -u $1)
    docker build -t jay -f ./Dockerfile_production --build-arg UID=$UID_SH .

    echo "Setup secret key and database"
    ./scripts/launch-docker.sh ./scripts/docker/docker-setup.sh
    ./scripts/launch-docker.sh stop

    echo "Done."
}

function usage() {
    cat <<_EOT_
setup-docker.sh <UserName>
<UserName> is the name of user that runs jay container.
_EOT_
}

function user_exists() {
    if id -u $1; then
        return 0
    else
        return 1
    fi
}

main $1
