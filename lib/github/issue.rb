module Github
  class Issue
    # webhook_payload
    # https://developer.github.com/v3/activity/events/types/#issuesevent
    def initialize(webhook_payload)
      @data = webhook_payload
    end

    def path
      "#{owner_name}/#{repository_name}/##{number}"
    end

    def action_item_uids
      body.split("\n").map do |line|
        $1 if /\[AI(\d{4})\]/ =~ line
      end.compact
    end

    def number
      @data['issue']['number']
    end

    def body
      @data['issue']['body']
    end

    def owner_name
      @data['repository']['owner']['login']
    end

    def repository_name
      @data['repository']['name']
    end
  end
end
