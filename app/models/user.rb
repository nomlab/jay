class User < ActiveRecord::Base
  has_many :minutes, :foreign_key => :author_id

  def self.current=(user)
    @current_user = user
  end

  def self.current
    @current_user
  end

  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth["provider"]
      user.uid      = auth["uid"]
      user.name     = auth["info"]["name"]
    end
  end

  # preparation for collaborating with octokit
  #
  # https://github.com/doorkeeper-gem/doorkeeper-devise-client/blob/master/app/controllers/application_controller.rb
  # https://github.com/intridea/omniauth-oauth2/blob/master/lib/omniauth/strategies/oauth2.rb
  #
  # oauth and octokit
  # https://gist.github.com/mattboldt/7865054
  #
  def github_access_token
    @client ||= ::OAuth2::Client.new(ApplicationSettings.oauth.github.client_id,
                                   ApplicationSettings.oauth.github.client_secret,
                                   :site => "https://api.github.com/")

    @token ||= ::OAuth2::AccessToken.new(@client, session[:access_token])
  end

  # github_access_token.get("/api/v1/posts", params: { post: { title: title, body: body } })
  # github_access_token.get()
  def github_api(method, request, params)
    github_access_token.send(method.to_s.downcase.to_sym,
                             request,
                             params: params).parsed
  end

  # https://github.com/jonmagic/omniauth-github-team-member/blob/master/lib/omniauth/strategies/github_team_member.rb
  def team_member?(team_id)
    response = github_access_token.get("/teams/#{team_id}/memberships/#{uid}")
    response.status == 200 && response.parsed["state"] == "active"
  rescue ::OAuth2::Error
    false
  end
end
