#!/bin/bash

echo "create master.key"
EDITOR=':' bundle exec rails credentials:edit

echo "migrate database"
bundle exec rails db:migrate RAILS_ENV=production
