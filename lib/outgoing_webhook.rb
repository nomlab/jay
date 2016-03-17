require 'net/http'
require 'uri'

class OutgoingWebhook
  attr_reader :uri

  def initialize(settings)
    @uri = URI.parse(settings["url"])
    @content_type = settings["content_type"]
    @events = settings["events"]
  end

  def post(content_hash)
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.request(generate_request(content_hash))
  end

  private

  def generate_request(content_hash)
    req = Net::HTTP::Post.new(@uri.request_uri)

    req["Content-Type"] = @content_type
    req.body = generate_body(content_hash)

    return req
  end

  def generate_body(content_hash)
    case @content_type
    when "application/json"
      content_hash.to_json
    else
      raise "Unknown Content-Type."
    end
  end
end
