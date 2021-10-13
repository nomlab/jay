#!/bin/bash

echo "chage ownership"
chown -R jay:jay /home/jay/*

echo "create master.key"
EDITOR=':' bundle exec rails credentials:edit

echo "migrate database"
bundle exec rails db:migrate RAILS_ENV=production
