json.array!(@minutes) do |minute|
  json.extract! minute, :id, :title, :dtstart, :dtend, :location, :author_id, :content
  json.url minute_url(minute, format: :json)
end
