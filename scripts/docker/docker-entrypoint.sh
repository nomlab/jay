#!/bin/bash

main() {
    cd "$(dirname "$0")"
    cd ../

    # run rails server
    export RAILS_ENV="production"
    export RAILS_SERVE_STATIC_FILES=true
    bundle exec rails assets:precompile RAILS_ENV="$RAILS_ENV"
    bundle exec rails s -b 0.0.0.0 -p 3000 -e "$RAILS_ENV" &

    # get pid of rails server
    pid=$!

    # stop server when receive SIGTERM
    trap 'signal_handler $pid' SIGTERM

    # wait for daemon stopping
    wait
}

signal_handler() {
    echo "Stopping process pid: $1"
    kill -2 $1
}

main
