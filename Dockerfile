# Dockerfile for jay
#   https://github.com/nomlab/jay
#
# To build image:
#   docker build -t jay .
#
# To run container:
#   docker run -t -i --rm --name "jay" -p 12321:12321 jay
#
# In jay container:
#
#   List available tasks:
#     bundle exec rake -T
#   Perform test:
#     bundle exec rake cucumber
#   Invoke jay server:
#     bundle exec rake sunspot:solr:start
#     bundle exec rails server -p 12321
#
# TODO:
#   RAILS_ENV is required for production
#   What locale and TZ are the best for production?
#
FROM ruby:2.4.3

ENV DEBIAN_FRONTEND noninteractive

# Set timezone
RUN echo Asia/Tokyo > /etc/timezone
RUN dpkg-reconfigure -f noninteractive tzdata

# Install required packages 
RUN apt-get update -qq \
    && apt-get install -y locales sudo build-essential git-core vim libsqlite3-dev nodejs\
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen ja_JP.UTF-8
ENV LANG ja_JP.UTF-8
ENV LANGUAGE ja_JP:ja
ENV LC_TIME C
RUN localedef -f UTF-8 -i ja_JP ja_JP.utf8

# Add jay user
RUN useradd -ms /bin/bash jay
RUN usermod -aG sudo jay
RUN sed -i 's/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# Copy app files from cwd
WORKDIR /home/jay
COPY . /home/jay
COPY config/application_settings_sample.yml config/application_settings.yml
RUN chown -R jay:jay /home/jay

# Switch user to jay
USER jay

# Setup Rails app (RAILS_ENV=development)
RUN gem install bundler
RUN bundle install --path=vendor/bundle
#RUN bundle exec rake db:migrate
#RUN bundle exec rake db:migrate RAILS_ENV=production

CMD ["bash"]
