class User < ApplicationRecord
  has_many :minutes, :foreign_key => :author_id

  validates_presence_of :provider, :uid, :screen_name

  validates_uniqueness_of :screen_name
  validates_uniqueness_of :uid, :scope => :provider

  validates_format_of :screen_name, :with => /\A[a-zA-Z\d]+(-[a-zA-Z\d]+)*\z/

  def self.current=(user)
    @current_user = user
  end

  def self.current
    @current_user
  end

  # Omniauth-github has these info:
  #   https://github.com/intridea/omniauth-github/blob/master/lib/omniauth/strategies/github.rb
  #
  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth["provider"]
      user.uid      = auth["uid"]

      info = auth["info"]
      user.name        = info["name"]
      user.screen_name = info["nickname"]
      user.avatar_url  = info["image"]
    end
  end

  attr_accessor :access_token

  # Re-create valid access token usable by OAuth2
  #
  # https://github.com/doorkeeper-gem/doorkeeper-devise-client/blob/master/app/controllers/application_controller.rb
  # https://github.com/intridea/omniauth-oauth2/blob/master/lib/omniauth/strategies/oauth2.rb
  #
  # User.current_access_token was extracted from request.env["omniauth.auth"]["credentials"]["token"] on callback
  #
  def github_access_token
    @client ||= ::OAuth2::Client.new(ApplicationSettings.oauth.github.client_id,
                                     ApplicationSettings.oauth.github.client_secret,
                                     :site => "https://api.github.com/")

    @token ||= ::OAuth2::AccessToken.new(@client, User.current.access_token)
  end

  # method: :get, :post, ...
  # request: https://api.github.com/....
  # params: {post: {title: title, body: body}}
  def github_api(method, request, params = nil)
    github_access_token.send(method.to_s.downcase.to_sym,
                             request,
                             params: params).parsed
  end

  # Get repository information using oauth
  def repos_via_current_oauth
    org = ApplicationSettings.github.organization
    array = github_api(:get, "https://api.github.com/orgs/#{org}/repos")
  end

  # Get repository information using octokit
  # https://gist.github.com/mattboldt/7865054
  def repos_octokit
    github = ::Octokit::Client.new(:access_token => User.current.access_token)
    array = github.organization_repositories(ApplicationSettings.github.organization)
  end

  alias_method :repos, :repos_via_current_oauth

  # https://github.com/jonmagic/omniauth-github-team-member/blob/master/lib/omniauth/strategies/github_team_member.rb
  def team_member?(team_id)
    response = github_access_token.get("/teams/#{team_id}/memberships/#{uid}")
    response.status == 200 && response.parsed["state"] == "active"
  rescue ::OAuth2::Error
    false
  end
end
