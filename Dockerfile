# Dockerfile for jay
#   https://github.com/nomlab/jay
#
# To build image:
#   docker build -t jay .
#
# To run container:
#   docker run -t -i --name "jay" -p 12321:12321 jay
#
# In jay container:
#   In config/application_settings.yml,
#   setup GitHub's organization, client_id, client_secret, and allowed_team_id

FROM ruby:3.0.0

ENV DEBIAN_FRONTEND noninteractive

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
ENV TZ Asia/Tokyo
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

# Install gem
RUN gem install bundler
RUN bundle config set path 'vendor/bundle'
RUN bundle install
CMD ["bash"]
