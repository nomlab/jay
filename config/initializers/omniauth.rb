Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
           ApplicationSettings.oauth.github.client_id,
           ApplicationSettings.oauth.github.client_secret,
           scope: "user,repo,gist",
           name: "github_anonymous"

  provider :githubteammember,
    ApplicationSettings.oauth.github.client_id,
    ApplicationSettings.oauth.github.client_secret,
    scope: 'read:org',
    teams: {
      "active_member?" => ApplicationSettings.oauth.github.allowed_team_id
    },
    name: "github"
end
