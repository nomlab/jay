if __FILE__ == $0
  ################################################################
  # rbenv support:
  # If this file is a symlink, and bound to a specific ruby
  # version via rbenv (indicated by RBENV_VERSION),
  # I want to resolve the symlink and re-exec
  # the original executable respecting the .ruby_version
  # which should indicate the right version.
  #
  if File.symlink?(__FILE__) and ENV["RBENV_VERSION"]
    ENV["RBENV_VERSION"] = nil
    shims_path = File.expand_path("shims", ENV["RBENV_ROOT"])
    ENV["PATH"] = shims_path + ":" + ENV["PATH"]
    exec(File.readlink(__FILE__), *ARGV)
  end

  gemfile = File.expand_path("../../Gemfile", __FILE__)

  if File.exists?(gemfile + ".lock")
    ENV["BUNDLE_GEMFILE"] = gemfile
    require "bundler/setup"
    Bundler.require
  end
  require "pp"
end


module Kramdown
  module Converter
    #
    # Convert parsed tree to line-numberd HTML
    # This class is refered from Kramdown::Document
    #
    class LineNumberedHtml < Html

      def initialize(root, options)
        super
        @root = options_to_attributes(@root, :location, "data-linenum")
      end

      private

      def options_to_attributes(el, option_name, attr_name)
        if el.options[option_name]
          el.attr[attr_name] = el.options[option_name]
        end
        el.children.each do |child|
          child = options_to_attributes(child, option_name, attr_name)
        end
        return el
      end

    end # class LineNumberedHtml
  end # module Converter
end # module Kramdown

#
# Convert Text to HTML filter conformed to HTML::Pipeline
# https://github.com/jch/html-pipeline
#
class JayFlavoredMarkdownFilter < HTML::Pipeline::TextFilter
  def call
    Kramdown::Document.new(@text, context).to_line_numbered_html.strip.force_encoding("utf-8")
  end
end

#
# Jay Flavored Markdown to HTML converter
#
# Octdown is a good example for making original converter.
# https://github.com/ianks/octodown/blob/master/lib/octodown/renderer/github_markdown.rb
#
class JayFlavoredMarkdownConverter

  def initialize(text, options = {})
    @text = text
    @options = options
  end

  def content
    pipeline.call(@text)[:output].to_s
  end

  private

  def context
    whitelist = HTML::Pipeline::SanitizationFilter::WHITELIST.dup
    whitelist[:attributes][:all] << "data-linenum"
    {
      asset_root: 'https://assets-cdn.github.com/images/icons/',
      whitelist: whitelist
    }
  end

  def pipeline
    HTML::Pipeline.new [
      JayFlavoredMarkdownFilter,
      HTML::Pipeline::AutolinkFilter,
      HTML::Pipeline::SanitizationFilter,
      HTML::Pipeline::ImageMaxWidthFilter,
      HTML::Pipeline::MentionFilter,
      HTML::Pipeline::EmojiFilter,
      HTML::Pipeline::SyntaxHighlightFilter,
    ], context.merge(@options)
  end
end

if __FILE__ == $0
  puts JayFlavoredMarkdownConverter.new(gets(nil)).content
end
