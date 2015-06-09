class User < ActiveRecord::Base
  has_many :minutes, :foreign_key => :author_id
end
