# -*- coding: utf-8 -*-
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
    when :item
      ListItemLeveledCounter.new
    when :section
      SectionCounter.new
    end
  end

  def initialize(init = init_values.take(1))
    @counter = init
  end

  def next
    new {|c| c[level] && c[level].succ!}
  end

  def next_level
    new {|c| c << init_values[level + 1]}
  end

  def previous_level
    new {|c| c.pop}
  end

  def reset
    new {|c| c[level] = init_values[level]}
  end

  def mark
    @counter[level]
  end

  def full_mark
    @counter.join(count_separator)
  end

  def type
    self.class::COUNTER_TYPE
  end

  def level
    @counter.size - 1
  end

  private

  def init_values
    self.class::INIT_VALUES
  end

  def count_separator
    self.class::COUNT_SEPARATOR
  end

  def new
    dup = @counter.map{|c| c && c.dup}
    yield dup
    self.class.new(dup)
  end
end

class ListItemLeveledCounter < LeveledCounter
  INIT_VALUES = ["1", "A", "a"]
  COUNT_SEPARATOR = '-'
  COUNTER_TYPE = :item

  def label
    mark && " (#{mark})"
  end
end

class SectionCounter < LeveledCounter
  INIT_VALUES = ["1", "1", "1"]
  COUNT_SEPARATOR = '.'
  COUNTER_TYPE = :section

  def label
    mark && " #{full_mark}"
  end
end

class MarkdownFeature
  def self.create(type)
    case type
    when :item
      ListItemFeature.new
    when :section
      SectionFeature.new
    end
  end

  def match_start_regexp?(string)
    start_regexp =~ string
  end

  def indent_length(line)
    indent =~ line ? $1.length : 0
  end

  def create_counter
    LeveledCounter.create(type)
  end

  def select_counter(counters)
    counters.find {|item| item.type == type}
  end

  private

  def type
    self.class::FEATURE_TYPE
  end

  def start_regexp
    self.class::START_REGEXP
  end

  def indent
    self.class::INDENT
  end
end

class ListItemFeature < MarkdownFeature
  START_REGEXP = /^\s*[+-] /
  INDENT = /^(\s*)/
  FEATURE_TYPE = :item

  def inside_of_list?(string, current_indent)
    return false if string.nil?
    return true if indent_length(string) > current_indent
    return true if string =~ /^\r*$/
    return false
  end
end

class SectionFeature < MarkdownFeature
  START_REGEXP = /^##+ /
  INDENT = /^#(#+)/
  FEATURE_TYPE = :section

  def inside_of_list?(string, current_indent)
    return false if string.nil?
    return true if indent_length(string) > current_indent
    return true unless match_start_regexp?(string)
    return false
  end
end

class MarkdownEnumerator
  def initialize(lines)
    @lines = lines
    @features = [MarkdownFeature.create(:item), MarkdownFeature.create(:section)]
  end

  def filter(&block)
    scan(@lines.dup, @features.map(&:create_counter), &block)
  end

  private

  def scan(lines, counters, &block)
    return [] if lines.empty?

    string = lines.shift
    children = []

    if (feature = @features.find {|item| item.match_start_regexp?(string)})
      counter = feature.select_counter(counters)

      indent = feature.indent_length(string)
      children << string

      while (string = lines.first) && feature.inside_of_list?(string, indent)
        children << lines.shift
      end

      return [yield(children.shift, counter)] +
             scan(children, next_level_counters(counters, counter), &block) +
             scan(lines, next_counters(counters, counter), &block)
    else
      return [string] + scan(lines, reset_counters(counters, counter), &block)
    end
  end

  def next_counters(counters, counter)
    counters.map {|item| item == counter ? item.next : item}
  end

  def next_level_counters(counters, counter)
    counters.map {|item| item == counter ? item.next_level : item}
  end

  def reset_counters(counters, counter)
    counters.map {|item| item == counter ? item.reset : item}
  end
end

################################################################
## Kramdown parser with Jay hack

module Kramdown
  module Parser
    class JayKramdown < GFM

      JAY_LIST_START_UL = /^(#{OPT_SPACE}[*])([\t| ].*?\n)/
      JAY_LIST_START_OL = /^(#{OPT_SPACE}(?:\d+\.|[+-]))([\t| ].*?\n)/

      def initialize(source, options)
        super
        @span_parsers.unshift(:label_tags)
        @span_parsers.unshift(:ref_tags)
      end

      def parse
        super
        @root = add_numbers_to_tree(@root)
      end

      # Override element type:
      # Original Kramdown parser recognizes '+' and '-' as UL.
      # However, Jay takes them as OL.
      def new_block_el(*args)
        if args[0] == :ul && @src.check(JAY_LIST_START_OL)
          args[0] = :ol
          super(*args)
        else
          super(*args)
        end
      end

      private

      LABEL_TAGS_START = /<<([^<>]+)>>/
      def parse_label_tags
        @src.pos += @src.matched_size
        @tree.children << Element.new(:label, @src[1])
      end
      define_parser(:label_tags, LABEL_TAGS_START, '<<')

      REF_TAGS_START = /\[\[(.*?)\]\]/
      def parse_ref_tags
        @src.pos += @src.matched_size
        @tree.children << Element.new(:ref, @src[1])
      end
      define_parser(:ref_tags, REF_TAGS_START, '\[\[')

      def enter_ol(el)
        if @label_counter
          @label_counter = @label_counter.next_level
        else
          @label_counter = LeveledCounter.create(:item)
        end
      end

      def exit_ol(el)
        @label_counter = @label_counter.previous_level
      end

      def visit_ol_li(el, first = false)
        @label_counter = @label_counter.next unless first
        el.value = @label_counter

        # XXX: Inject text bullet (A) next to the LI tag.
        #      This code should be in Converter#convert_li
        label = Element.new(:text, "(#{@label_counter.mark}) ")
        if el.children.empty? || Element.category(el.children.first) != :block
          el.children.unshift(label)
        else
          el.children.first.children.unshift(label)
        end
      end

      def visit_ol(el)
        enter_ol(el)
        first = true
        el.children.each do |child|
          if child.type == :li
            visit_ol_li(child, first)
            first = false
          end
          add_numbers_to_tree(child)
        end
        exit_ol(el)
      end

      def add_numbers_to_tree(el)
        if el.type == :ol
          visit_ol(el)
        else
          el.children.each do |child|
            add_numbers_to_tree(child)
          end
        end
        return el
      end
    end
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
        @xref_table = {}
        @root = options_to_attributes(@root, :location, "data-linenum")
        # @root = add_numbers_to_li_text(@root)
        @root = make_xref(@root)
        # debug_dump_tree(@root)
        @root
      end

      private

      def debug_dump_tree(tree, indent = 0)
        STDERR.print " " * indent
        STDERR.print "#{tree.type} #{tree.value}\n"
        tree.children.each do |c|
          debug_dump_tree(c, indent + 2)
        end
      end

      def convert_ref(el, indent)
        if @xref_table[el.value]
          "(#{@xref_table[el.value].full_mark})"
        else
          "(???)"
        end
      end

      def convert_label(el, indent)
        ""
      end

      def find_first_type(el, type)
        return el if [type].flatten.include?(el.type)
        el.children.each do |c|
          if element = find_first_type(c, type)
            return element
          end
        end
        return nil
      end

      def make_xref(el)
        if el.type == :li && el.value && (label = find_first_type(el, :label))
          @xref_table[label.value] = el.value
        end
        el.children.each do |child|
          make_xref(child)
        end
        return el
      end

      # def add_numbers_to_li_text(el)
      #   if el.type == :li && el.value && (text = find_first_type(el, [:ref, :text]))
      #     STDERR.print "TEXT #{text.type}\n"
      #     if text.type == :text
      #       text.value = "(#{el.value.mark}) #{text.value}"
      #     else
      #       # :ref
      #       # XXX
      #     end
      #   end
      #   el.children.each do |child|
      #     add_numbers_to_li_text(child)
      #   end
      #   return el
      # end

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
    Kramdown::Document.new(@text, {
                             input: "JayKramdown",
                             # syntax_highlighter: :rouge,
                             # syntax_highlighter_opts: {
                             #  line_numbers: true,
                             #  css_class: 'codehilite'
                             # }
                           }
                          ).to_line_numbered_html.strip.force_encoding("utf-8")
  end
end


################################################################
## Markdown to Markdown filters

#
# Fix the depth of the indent to multiple of 4(INDENT_DEPTH)
#
class JayFixIndentDepth < HTML::Pipeline::TextFilter
  INDENT_DEPTH = 4

  def call
    lines = @text.split("\n")
    items = MarkdownEnumerator.new(lines)

    @text = items.filter do |header, count|
      header.sub(/^(\s*)([*+-])(\s+)/){|x| "#{valid_indent(count)}#{$2}#{$3}"}
    end.join("\n")
  end

  private

  def valid_indent(count)
    " " * INDENT_DEPTH * count.level
  end
end

#
# Convert list item header ``+`` text to ``+ (A)``
#
class JayAddLabelToListItems < HTML::Pipeline::TextFilter
  def call
    lines = @text.split("\n")
    items = MarkdownEnumerator.new(lines)

    # store <<name>> to hash
    @text = items.filter do |header, count|
      header.sub(/^(\s*[+-]|##+)(\s+)/){|x| "#{$1}#{count.label}#{$2}"}
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
    @labels = {}
    lines = @text.split("\n")

    # Scan "<<name>>" and make hash {"name" => "C"}
    lines = MarkdownEnumerator.new(lines).filter do |header, count|
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
    @labels[key] = value
  end

  def lookup_label(key)
    return @labels[key]
  end
end

#
# Remove markup elements(*, +, -, #, [])
#
class JayRemoveMarkupElements < HTML::Pipeline::TextFilter
  def call
    @text = @text.split("\n").map do |line|
      line = remove_emphasis(line)
      line = remove_header(line)
      line = remove_link(line)
      line = remove_list(line)
      line = remove_strikethrough(line)
    end.join("\n")
  end

  private

  # Remove " _hoge_ ", " *fuga* "
  def remove_emphasis(line)
    return line.gsub(/\s([\_\*])([^\1]+?)\1\s/, '\2')
  end

  # Remove "#"
  def remove_header(line)
    return line.gsub(/\A#+\s+(.*)/, '\1')
  end

  # Remove "[title](link)"
  def remove_link(line)
    return line.gsub(/(\[.*\])\(.*?\)/, '\1')
  end

  # Remove "*", "+", "-"
  def remove_list(line)
    return line.gsub(/[\*\+\-]\s+/, '')
  end

  # Remove " ~hoge~ "
  def remove_strikethrough(line)
    return line.gsub(/\s~([^~]+?)~\s/, '\1')
  end
end

#
# Fill columns with MAX_COLUMN characters in one line
#
#   (1) One sheep, two sheep, three sheep, four sheep, five sheep.
#     (A) Six sheep, seven sheep, eight sheep, nine sheep, ten sheep.
#
# is converted to:
#
#   (1) One sheep, two sheep, three sheep, four
#       sheep, five sheep.
#     (A) Six sheep, seven sheep, eight sheep,
#         nine sheep, ten sheep.
#
class JayFillColumns < HTML::Pipeline::TextFilter
  MAX_COLUMN = 70

  def call
    lines = @text.split("\n")
    @text = lines.map do |line|
      pos = paragraph_position(line)
      fill_column(line, MAX_COLUMN, pos, ' ')
    end.join("\n")
  end

  private

  def character_not_to_allow_newline_in_word?(c)
    newline = "\n\r"
    symbol = "-,.，．"
    small_kana = "ぁぃぅぇぉゃゅょゎァィゥェォャュョヮ"
    return !!(c =~ /[a-zA-Z#{newline}#{symbol}#{small_kana}]/)
  end

  # Get position of beginning of line after second line
  def paragraph_position(str)
    # Example1: " No.100-01 :: Minutes of GN meeting"
    #                         ^
    # Example2: " (A) This is ...."
    #                ^
    if /(\A\s*([^\s]+ ::|\(.+\)) +)/ =~ str
      return str_mb_width($1)
    else
      return 0
    end
  end

  # Get width of a character considering multibyte character
  def char_mb_width(c)
    return 0 if c == "\r" || c == "\n" || c.empty?
    return c.ascii_only? ? 1 : 2
  end

  # Get width of string considering multibyte character
  def str_mb_width(str)
    return 0 if str.empty?
    return str.each_char.map{|c| char_mb_width(c)}.inject(:+)
  end

  # str       : String, not including newline
  # max_width : Max width in one line
  # positon   : Position of beginning of line after second line
  # padding   : Character used padding
  def fill_column(str, max_width, position, padding)
    return str if max_width >= str_mb_width(str)

    i = 0; width = 0
    begin
      width += char_mb_width(str[i])
    end while width <= max_width && i += 1

    i += 1 while character_not_to_allow_newline_in_word?(str[i])

    if str.length > i + 1
      x = str[0..(i-1)] + "\n"
      xs = "#{padding * position}" + str[i..(str.length-1)]
      return x + fill_column(xs, max_width, position, padding)
    else
      return str
    end
  end
end

#
# Shorten 4 indent to 2 indent.
#
class JayShortenIndent < HTML::Pipeline::TextFilter
  def call
    @text = @text.split("\n").map do |line|
      shorten_indent(line)
    end.join("\n")
  end

  private

  def shorten_indent(line)
    return line unless /\A(\s+)(.*)/ =~ line
    indent_depth = $1.length / 2
    return "#{' ' * indent_depth}#{$2}"
  end
end

class JayAddLink < HTML::Pipeline::TextFilter
  def call
    lines = @text.split("\n")

    # Replace GitHub issue notation into solid markdown link.
    # Example:
    #   nomlab/jay/#10
    # becomes:
    #   [nomlab/jay/#10](https://github.com/nomlab/jay/issues/10){:.github-issue}
    #
    # NOTE: {:.foo} is a kramdown dialect to add class="foo" to HTML.
    @text = lines.map do |line|
      line.gsub(%r{(?:([\w.-]+)/)??(?:([\w.-]+)/)?#(\d+)}i) do |match|
        url = "https://github.com/#{$1 || context[:organization]}/#{$2}/issues/#{$3}"
        "[#{match}](#{url}){:.github-issue}"
      end
    end

    # Replace action-item notation into solid markdown link.
    # Example:
    #   -->(name !:0001) becomes [-->(name !:0001)](){:data-action-item="0001"}
    #
    # NOTE: {:attr=val} is a kramdown dialect to add attribute to DOM element.
    @text = @text.map do |line|
      line.gsub(/-->\((.+?)!:([0-9]{4})\)/) do |macth|
        assignee, action = $1.strip, $2.strip
        "[-->(#{assignee} !:#{action})](){:.action-item}{:data-action-item=\"#{action}\"}"
      end
    end.join("\n")
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
      whitelist: whitelist,
      syntax_highlighter: :rouge,
      syntax_highlighter_opts: {inline_theme: true, line_numbers: true, code_class: 'codehilite'}
    }
  end

  def pipeline
    HTML::Pipeline.new [
      JayFixIndentDepth,
      JayAddLink,
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

#
# Jay Flavored Markdown to Plain Text converter
#
class JayFlavoredMarkdownToPlainTextConverter

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
      JayFixIndentDepth,
      JayAddLabelToListItems,
      JayAddCrossReference,
      JayRemoveMarkupElements,
      JayShortenIndent,
      JayFillColumns,
    ], context.merge(@options)
  end
end

if __FILE__ == $0
  puts <<-EOF
    <style>
      ol {list-style-type: none;}
    </style>
  EOF
  puts JayFlavoredMarkdownConverter.new(gets(nil)).content
end
