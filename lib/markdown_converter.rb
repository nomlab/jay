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
# Convert list item header ``+`` text to ``+ (A)``
#
class JayAddLabelToListItems < HTML::Pipeline::TextFilter
  def call
    @text = insert_label(@text.split("\n"), 1).join("\n")
  end

  private

  def make_label_text(level, count)
    labels = [
      (  1 .. 100).to_a,
      ("A" .. "Z").to_a,
      ("a" .. "z").to_a,
    ]
    return labels[level - 1][count - 1].to_s
  end

  def insert_label_char(line, level, count)
    if /^(\s*)([+-]) (.*)/ =~ line
      char = make_label_text(level, count)
      return $1 + $2 + " (#{char}) " + $3
    else
      return line
    end
  end

  def indent_length(line)
    if /^(\s*)/ =~ line
      return $1.length
    end
    return 0
  end

  def insert_label(lines, level, count = 1)
    return [] if lines.empty?

    string = lines.shift
    item = []

    if /^(\s*)([+-]) (.*)/ =~ string
      indent = $1.length
      item << string

      while lines[0] && (indent_length(lines[0]) > indent ||
                         lines[0] =~ /^\r*$/)
        item << lines.shift
      end

      return [insert_label_char(item[0], level, count)] +
             insert_label(item[1..-1], level + 1) +
             insert_label(lines, level, count + 1)
    else
      return [string] + insert_label(lines, level)
    end
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
      input: "GFM",
      asset_root: 'https://assets-cdn.github.com/images/icons/',
      whitelist: whitelist
    }
  end

  def pipeline
    HTML::Pipeline.new [
      JayAddLabelToListItems,
      JayFlavoredMarkdownFilter,
      HTML::Pipeline::AutolinkFilter,
      # HTML::Pipeline::SanitizationFilter,
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
