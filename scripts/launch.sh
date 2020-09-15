#!/bin/sh
export RAILS_SERVE_STATIC_FILES=true
bundle exec rake assets:precompile RAILS_ENV=production
bundle exec rails s -e production -p 12321 -d -b 0.0.0.0
