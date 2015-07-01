module ApplicationHelper
  def glyphicon(name)
    raw %(<span class="glyphicon glyphicon-#{name}" aria-hidden="true"></span>)
  end

  def new_content(path)
    link_to glyphicon("plus"), path,  type: "button", class: "btn btn-default"
  end
end
