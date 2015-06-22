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

################################################################
## Helper classes to manipulate list items
class LeveledCounter
  def self.create(type)
    case type
    when :minute
      MinuteLeveledCounter.new
    when :section
      SectionCounter.new
    end
  end

  def next
    new {|c| c[level].succ!}
  end

  def next_level
    new {|c| c << @initial[level + 1]}
  end
  
  def reset
    new {|c| c[level] = @initial[level]}
  end

  def mark
    @counter[level]
  end

  def full_mark
    @counter.join(@count_separator)
  end

  private

  def level
    @counter.size - 1
  end

  def new
    dup = @counter.map{|c| c && c.dup}
    yield dup
    self.class.new(dup)
  end
end

class MinuteLeveledCounter < LeveledCounter
  INIT_VALUES = ["1", "A", "a"]

  def initialize(init = INIT_VALUES.take(1))
    @initial = INIT_VALUES
    @count_separator = '-'
    @counter = init
  end
end

class SectionCounter < LeveledCounter
  INIT_VALUES = ["1", "1", "1"]
  
  def initialize(init = INIT_VALUES.take(1))
    @initial = INIT_VALUES
    @count_separator = '.'
    @counter = init
  end
end

class ListItemEnumerator
  LIST_ITEM_START_REGEXP = /^\s*[+-] /

  def initialize(lines)
    @lines = lines
  end

  def filter(type, &block)
    scan(@lines.dup, LeveledCounter.create(type), &block)
  end

  private

  def scan(lines, counter, &block)
    return [] if lines.empty?

    string = lines.shift
    items = []

    if LIST_ITEM_START_REGEXP =~ string
      indent = indent_length(string)
      items << string

      while (string = lines.first) && inside_of_list?(string, indent)
        items << lines.shift
      end

      return [yield(items.shift, counter)] +
             scan(items, counter.next_level, &block) +
             scan(lines, counter.next, &block)
    else
      return [string] + scan(lines, counter.reset, &block)
    end
  end

  def indent_length(line)
    /^(\s*)/ =~ line ? $1.length : 0
  end

  def inside_of_list?(string, current_indent)
    return false if string.nil?
    return true if indent_length(string) > current_indent
    return true if string =~ /^\r*$/
    return false
  end
end

################################################################
## Kramdown to HTML converter with additions

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


################################################################
## Markdown to Markdown filters

#
# Convert list item header ``+`` text to ``+ (A)``
#
class JayAddLabelToListItems < HTML::Pipeline::TextFilter
  def call
    lines = @text.split("\n")
    items = ListItemEnumerator.new(lines)

    # store <<name>> to hash
    @text = items.filter(:minute) do |header, count|
      header.sub(/^(\s*)([+-])(\s+)/){|x| "#{$1}#{$2} (#{count.mark})#{$3}"}
    end.join("\n")
  end
end

#
# Org-mode like label and ref converter
#
#   + (1)
#     + (A) item title <<title>>
#   ...
#   item [[title]] is...
#
# is converted to:
#
#   + (1)
#     + (A) item title
#   ...
#   item (1-A) is...
#
class JayAddCrossReference < HTML::Pipeline::TextFilter
  def call
    lines = @text.split("\n")

    # Scan "<<name>>" and make hash {"name" => "C"}
    lines = ListItemEnumerator.new(lines).filter(:minute) do |header, count|
      header.gsub(/<<([^<>]+)>>/) do |_|
        store_label($1, count.full_mark)
        ""
      end
    end

    # replace "[[name]]" to "(C)"
    @text = lines.map do |line|
      line.gsub(/\[\[([^\[\]]+)\]\]/) do |match|
        "(#{lookup_label($1) || '???'})"
      end
    end.join("\n")
  end

  private

  def store_label(key, value)
    @labels ||= {}
    @labels[key] = value
  end

  def lookup_label(key)
    return @labels[key]
  end
end

################################################################
## HTML to HTML filters

#
# Add span tags and css classes to list headers.
#
# before:
#   <ul>
#     <li>(1) item header1</li>
#     <li>(2) item header2</li>
#   </ul>
#
# after:
#   <ul>
#     <li class="bullet-list-item">
#       <span class="bullet-list-marker">(1)</span> item header1
#     </li>
#     <li class="bullet-list-item">
#       <span class="bullet-list-marker">(2)</span> item header2
#     </li>
#   </ul>
#
class JayCustomItemBullet
  def self.filter(*args)
    Filter.call(*args)
  end

  class Filter < HTML::Pipeline::Filter
    BulletPattern = /\(([a-zA-Z]|\d+)\)/.freeze

    # Pattern used to identify all ``+ (1)`` style
    # Useful when you need iterate over all items.
    ItemPattern = /
      ^
      (?:\s*[-+*]|(?:\d+\.))? # optional list prefix
      \s*                     # optional whitespace prefix
      (                       # checkbox
        #{BulletPattern}
      )
      (?=\s)                  # followed by whitespace
    /x

    ListItemSelector = ".//li[bullet_list_item(.)]".freeze

    class XPathSelectorFunction
      def self.bullet_list_item(nodes)
        nodes if nodes.text =~ ItemPattern
      end
    end

    # Selects first P tag of an LI, if present
    ItemParaSelector = "./p[1]".freeze

    # List of `BuletList::Item` objects that were recognized in the document.
    # This is available in the result hash as `:bullet_list_items`.
    #
    # Returns an Array of BulletList::Item objects.
    def bullet_list_items
      result[:bullet_list_items] ||= []
    end

    # Public: Select all bullet lists from the `doc`.
    #
    # Returns an Array of Nokogiri::XML::Element objects for ordered and
    # unordered lists.
    def list_items
      doc.xpath(ListItemSelector, XPathSelectorFunction)
    end

    # Filters the source for bullet list items.
    #
    # Each item is wrapped in HTML to identify, style, and layer
    # useful behavior on top of.
    #
    # Modifications apply to the parsed document directly.
    #
    # Returns nothing.
    def filter!
      list_items.reverse.each do |li|
        # add_css_class(li.parent, 'bullet-list')

        outer, inner =
          if p = li.xpath(ItemParaSelector)[0]
            [p, p.inner_html]
          else
            [li, li.inner_html]
          end
        if match = (inner.chomp =~ ItemPattern && $1)
          # item = Bullet::Item.new(match, inner)
          # prepend because we're iterating in reverse
          # bullet_list_items.unshift item

          add_css_class(li, 'bullet-list-item')
          outer.inner_html = render_bullet_list_item(inner)
        end
      end
    end

    def render_bullet_list_item(item)
      Nokogiri::HTML.fragment \
        item.sub(ItemPattern, '<span class="bullet-list-marker">\1</span>'), 'utf-8'
    end

    def call
      filter!
      doc
    end

    # Private: adds a CSS class name to a node, respecting existing class
    # names.
    def add_css_class(node, *new_class_names)
      class_names = (node['class'] || '').split(' ')
      return if new_class_names.all? { |klass| class_names.include?(klass) }
      class_names.concat(new_class_names)
      node['class'] = class_names.uniq.join(' ')
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
      JayAddCrossReference,
      JayFlavoredMarkdownFilter,
      JayCustomItemBullet::Filter,
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
