source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.0.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0'
# Use sqlite3 as the database for Active Record
gem 'sqlite3'
# Use Puma as the app server
gem 'puma', '~> 3.11'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 2.15'
  gem 'selenium-webdriver'
  # Easy installation and use of chromedriver to run system tests with Chrome
  gem 'chromedriver-helper'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

################################################################
## User settings

gem 'jquery-rails'

# pure-ruby markdown to HTML converter
gem "kramdown", "~> 2.0"
gem 'kramdown-parser-gfm'

################
# html-pipeline filter
# https://github.com/jch/html-pipeline#dependencies
# See html-pipeline's Gemfile :test block for version requirements.
#
gem 'html-pipeline', '~> 2.14.0'
gem 'rinku'    ## for AutolinkFilter
gem 'gemoji'   ## for EmojiFilter
gem 'sanitize' ## for SanitizationFilter
gem 'rouge'    ## for SyntaxHighlightFilter

# OmniAuth + github
gem 'omniauth', '~> 1.9'
gem 'omniauth-github'
gem "omniauth-github-team-member"

# application settings
gem "settingslogic"

# Octokit -- Github access lib
gem "octokit"

# for Emoji completion
gem 'jquery-textcomplete-rails'

# https://github.com/twbs/bootstrap-sass
gem 'bootstrap-sass', '~> 3.3.4'

# haml
gem 'haml-rails'

# for extension font
gem 'font-awesome-sass', '~> 4.0'

gem 'kaminari'
gem 'kaminari-bootstrap'
