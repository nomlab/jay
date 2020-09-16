#!/bin/sh

# export RAILS_RELATIVE_URL_ROOT='/lab/nom'

# Rails 4 requires bundler < 2.0
# You may need to:
#   gem install bundler -v "< 2.0"
#   bundle _1.17.3_ install
#
# BUNDLER_VER="_1.17.3_"

BUNDLER_VER=""

case "$1" in
  dev*)
    export RAILS_ENV="development"
    export SERVER_PORT=3000
    ;;
  pro*)
    export RAILS_ENV="production"
    export SERVER_PORT=12321
    bundle $BUNDLER_VER exec rake assets:precompile RAILS_ENV="$RAILS_ENV"
    export RAILS_SERVE_STATIC_FILES=true
    ;;
  *)
    echo "usage: launch.sh (production|development)" >&2
    exit 1
    ;;
esac

bundle $BUNDLER_VER exec rails server -b 0.0.0.0 -p "$SERVER_PORT" -d -e "$RAILS_ENV"
