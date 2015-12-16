class ActionItem < ActiveRecord::Base
  def uid
    "%04d" % self.id
  end
end
