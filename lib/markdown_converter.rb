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
  def initialize(init = [0])
    @counter = init
  end

  def next
    new {|c| c[-1] += 1}
  end

  def next_level
    new {|c| c << 0}
  end

  def reset
    new {|c| c[-1] = 0}
  end

  def mark
    num_to_mark(@counter.size, @counter.last)
  end

  def full_mark
    @counter.map.with_index do |num, index|
      num_to_mark(index + 1, num)
    end.join("-")
  end

  private

  def num_to_mark(depth, num)
    mark = [1, "A", "a"][depth - 1]
    code = mark.ord + num
    mark.is_a?(String) ? code.chr : code
  end

  def new
    dup = @counter.dup
    yield dup
    self.class.new(dup)
  end
end

class ListItemEnumerator
  LIST_ITEM_START_REGEXP = /^\s*[+-] /

  def initialize(lines)
    @lines = lines
  end

  def filter(&block)
    scan(@lines.dup, LeveledCounter.new, &block)
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
    @ref_table = Hash.new
    lines = @text.split("\n")
    lines = find_label(lines, [])
    @text = replace_label(lines)
  end

  private

  def find_label(lines, stack)
    return [] if lines.empty?
    string = lines.shift
    item = []

    if /^(\s*)[*+-]\s*\((.*)\)(.*)/ =~ string
      label_number = $2
      item << string
      indent = $1.length
      while lines[0] && (indent_length(lines[0]) > indent ||
                         lines[0] =~ /^\r*$/)
        item << lines.shift
      end
      current_stack = stack + [label_number]
      return [entry_label(item[0], current_stack)] +
             find_label(item[1..-1], current_stack) +
             find_label(lines, stack)
    else
      return [string] + find_label(lines, stack)
    end
  end

  def replace_label(lines)
    lines.map do |line|
      if /(.*)\[\[(.+)\]\](.*)/ =~ line
        ref = @ref_table[$2] ? "(#{@ref_table[$2].join("-")})" : "[[#{$2}]]"
        $1 + "#{ref}" + $3
      else
        line
      end
    end.join("\n")
  end

  def indent_length(line)
    if /^(\s*)/ =~ line
      return $1.length
    end
    return 0
  end

  def entry_label(string, stack)
    if /.*\<\<(.*)\>\>$/ =~ string
      @ref_table[$1] = stack
      string.sub(/\<\<.+\>\>/, '')
    elsif
      string
    end
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
