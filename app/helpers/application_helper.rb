module ApplicationHelper
  def glyphicon(name, screen_reader = nil)
    raw %(<span class="glyphicon glyphicon-#{name}" aria-hidden="true"><span class="sr-only">#{screen_reader||name}</span></span>)
  end

  def new_content(name)
    path = self.send("new_#{name}_path")
    link_to glyphicon("plus", "New #{name}"), path, type: "button", class: "btn btn-default"
  end

  def tag_label(tag)
    raw %(<span class="label label-primary tag-label"><span class="glyphicon glyphicon-tag"></span> #{tag.name}</span>)
  end
end
