#!/bin/bash

cd $(dirname $0)
cd ../

echo "Create jay image"
UID_SH=$(id -u)
docker build -t jay -f ./Dockerfile_production --build-arg UID=$UID_SH .

echo "Setup secret key and database"
./scripts/launch-docker.sh ./scripts/docker/docker-setup.sh
./scripts/launch-docker.sh stop

echo "Done."
