require 'net/http'
require 'uri'

class Minute < ActiveRecord::Base
  belongs_to :author, :class_name => "User", :foreign_key => :author_id
  has_and_belongs_to_many :tags
  after_save :post_json

  def organization
    ApplicationSettings.github.organization
  end

  private

  def post_json
    uri = URI.parse(ApplicationSettings.post_url)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Post.new(uri.request_uri)

    req["Content-Type"] = "application/json"
    req.body = self.to_json

    logger.info "Posting minutes to #{ApplicationSettings.post_url}"

    res = http.request(req)

    logger.info "  Response: #{res.code} #{res.message}"
  end
end
