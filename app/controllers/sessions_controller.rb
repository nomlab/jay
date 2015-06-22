class SessionsController < ApplicationController
  skip_before_filter :authenticate

  def logout
    session[:user_id] = nil
    session[:access_token] = nil
    redirect_to root_path, :notice => "User logout."
  end

  def create
    auth = request.env["omniauth.auth"]

    unless auth.credentials.active_member?
      render text: "Unauthorized", status: 401
      return false
    end

    user = User.find_by_provider_and_uid(auth["provider"], auth["uid"]) ||
           User.create_with_omniauth(auth)

    session[:user_id] = user.id
    session[:access_token] = auth["credentials"]["token"]
    redirect_to '/', :notice => "User #{user.name} signed in."
  end
end
