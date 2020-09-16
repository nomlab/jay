class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  prepend_before_action :login_state_setup
  before_action :authenticate
  # after_action :outgoing_webhook_action

  private
  def login_state_setup
    if session[:user_id]
      User.current = User.find_by_id(session[:user_id])
    else
      User.current = nil
    end

    if User.current
      User.current.access_token = session[:access_token]
    end

    return true
  end

  def authenticate
    return true if User.current

    session[:jumpto] = request.parameters
    redirect_to root_path
    return false
  end

  def outgoing_webhook_action
    settings = ApplicationSettings.outgoing_webhooks.select do |setting|
      setting["events"].include?(action_name)
    end
    webhooks = settings.map {|setting| OutgoingWebhook.new(setting)}

    if @payload
      webhooks.each do |webhook|
        logger.info "Posting minutes to #{webhook.uri}"

        begin
          res = webhook.post(@payload)
          logger.info "  Response: #{res.code} #{res.message}"
        rescue => e
          flash[:error] = e.message
          logger.info ("  " + e.message)
        end
      end
    end
  end
end
