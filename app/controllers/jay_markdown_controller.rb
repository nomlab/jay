require "markdown_converter"

class JayMarkdownController < WebsocketRails::BaseController

  def convert
    markdown = message()
    html = ::JayFlavoredMarkdownConverter.new(markdown).content
    broadcast_message(:convert_markdown, html)
  end
end
