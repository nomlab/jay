class User < ActiveRecord::Base
  has_many :minutes, :foreign_key => :author_id

  def self.current=(user)
    @current_user = user
  end

  def self.current
    @current_user
  end

  def self.current_access_token=(token)
    @current_access_token = token
  end

  def self.current_access_token
    @current_access_token
  end

  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth["provider"]
      user.uid      = auth["uid"]
      user.name     = auth["info"]["name"]
    end
  end

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

    @token ||= ::OAuth2::AccessToken.new(@client, User.current_access_token)
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
  def repos
    github = ::Octokit::Client.new(:access_token => User.current_access_token)
    array = github.organization_repositories(ApplicationSettings.github.organization)
  end

  # https://github.com/jonmagic/omniauth-github-team-member/blob/master/lib/omniauth/strategies/github_team_member.rb
  def team_member?(team_id)
    response = github_access_token.get("/teams/#{team_id}/memberships/#{uid}")
    response.status == 200 && response.parsed["state"] == "active"
  rescue ::OAuth2::Error
    false
  end
end
