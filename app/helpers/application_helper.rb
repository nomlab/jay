module ApplicationHelper
  def glyphicon(name)
    raw %(<span class="glyphicon glyphicon-#{name}" aria-hidden="true"></span>)
  end
end
