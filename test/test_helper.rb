ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  # テストユーザーとしてログインする
  def log_in_as(user)
    OmniAuth.config.mock_auth[:github] =
      OmniAuth::AuthHash.new({
                               :provider => 'github',
                               :uid => user.id,
                               :credentials => {
                                 :token => 'mock_token',
                                 :active_member => 'mock_active_member'
                               },
                               :info => {
                                 :nickname => 'nickname',
                                 :name => 'name',
                                 :image => 'image'
                               }
                             })

    get '/auth/github/callback'
  end
end
