class Minute < ActiveRecord::Base
  belongs_to :author, :class_name => "User", :foreign_key => :author_id
  has_and_belongs_to_many :tags

  def organization
    ApplicationSettings.github.organization
  end
end
