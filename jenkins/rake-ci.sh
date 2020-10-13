#!/bin/bash

source /etc/profile.d/rvm.sh
rvm use 2.5.8

bundle config set app_config ${WORKSPACE}/.bundle
rsync -a /home/jenkins/app/ ${WORKSPACE}/
bundle config set path ${WORKSPACE}/vendor/bundle

bundle check
rvm 2.5.8 do bundle exec rake ci
