json.array!(@users) do |user|
  json.extract! user, :id, :screen_name, :name
  json.url user_url(user, format: :json)
end
