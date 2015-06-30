# jay

jay is a simple markdown editor for memo and taking minutes

## Table of Contents

- [Install](#install)

## Install

1.  Install rbenv and ruby-build (Click here for details
    [<https://github.com/sstephenson/rbenv#basic-github-checkout>](https://github.com/sstephenson/rbenv#basic-github-checkout)):

    ``` sh
    $ git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
    $ git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    # Edit your shell dot files to add some path and environment variables.
    ```

2.  Install Ruby and bundler:

    ``` sh
    # Install ruby 2.2.1
    $ rbenv install 2.2.1

    # Installation check
    $ rbenv global 2.2.1
    $ ruby -v # -> You will see: ruby 2.2.1...

    # Install bundler for your new Ruby
    $ gem install bundler

    # Activate bundler
    $ rbenv rehash

    # Get back to your sytem default Ruby if you want
    $ rbenv global system # say, /usr/bin/ruby
    $ ruby -v
    ```

3.  Clone the repo: `git clone git@github.com:nomlab/jay.git`
4.  Install gems:

    ``` sh
    $ cd jay
    $ bundle install --path vendor/bundle
    ```

5.  Migrate DB: `bundle exec rake db:migrate`
6.  set config/application_settings.yml:

    ``` sh
    $ mv config/application_settings_sample.yml config/application_settings.yml
    $ vim config/application_settings.yml # -> Replace XXXX to real value
    ```
