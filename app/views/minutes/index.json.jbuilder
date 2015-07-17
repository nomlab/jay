json.array!(@minutes) do |minute|
  json.extract! minute, :id, :title, :dtstart, :dtend, :location, :author_id, :content, :tag_ids
  json.url minute_url(minute, format: :json)
end
