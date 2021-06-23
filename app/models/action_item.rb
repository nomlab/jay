class ActionItem < ApplicationRecord
  after_create :set_uid

  def uid
    "%04d" % self.id
  end

  private

  def set_uid
    self.update(uid: uid)
  end
end
