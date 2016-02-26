class ActionItem < ActiveRecord::Base
  before_save :set_uid

  def uid
    "%04d" % self.id
  end

  private

  def set_uid
    self.uid = uid
  end
end
