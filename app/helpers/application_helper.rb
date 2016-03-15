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

  def bootstrap_class_for(flash_type)
    { success: "alert-success", error: "alert-danger",
      alert: "alert-warning", notice: "alert-info" }[flash_type.to_sym] || flash_type.to_s
  end

  def flash_messages(opts = {})
    flash.each do |flash_type, message|
      concat(
        content_tag(:div, message, class: "alert alert-dismissable #{bootstrap_class_for(flash_type)} fade in") do
          concat(
            content_tag(:button, class: "close", data: { dismiss: "alert" }) do
              concat content_tag(:span, "&times;".html_safe)
            end
          )
          concat message
        end
      )
    end
  end
end
