class IncomingWebhookController < ApplicationController

  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate

  def github
    payload_body = request.body.read
    verify_github_signature(payload_body)

    event = request.headers[:'X-Github-Event']
    payload = JSON.parse(payload_body)

    case event
    when 'issues'
      issue = Github::Issue.new(payload)
      ais = issue.action_item_uids.map do |uid|
        ai = ActionItem.find_by_uid(uid)
        ai.update(github_issue: issue.path)
        ai
      end
      render json: ais
    else
      render text: "Behavior for #{event} is undefined.", status: 400
    end
  end

  private

  def verify_github_signature(payload_body)
    incoming_webhooks = ApplicationSettings.incoming_webhooks.
               select{ |incoming_webhook| incoming_webhook.strategy == 'github' }

    signatures = incoming_webhooks.map do |incoming_webhook|
      'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'),
                                        incoming_webhook.token,
                                        payload_body)
    end

    render status: 401 unless signatures.any?{ |signature| Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE']) }
  end
end
