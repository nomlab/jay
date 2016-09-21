# -*- coding: utf-8 -*-
#
#--
# Copyright (C) 2016 Nomura Laboratory
#
# This file is NOT part of kramdown and is licensed under the MIT.
#++
#

require 'kramdown/parser'
require 'kramdown/converter'
require 'kramdown/utils'

# block 間の明示的な改行は， :blank エレメントとしてパーズされる
# span 中の改行は， :text エレメント中に残り，かつ，:br が挟まる
#
# + :blank は，そのまま反映する
# + span 中の改行と :br は全て削る
# + block の後には改行を1つ入れるが，block がネストしている場合は，改行が続くので，1つに集約する
#
# block は，通常インデントする必要はない．
# :root, :blank, :p, :header, :hr, :table, :tr, :td
#
# 以下のブロックは，インデントをする
# :blockquote, :codeblock
#
# :ul, :ol，:li, :dl  はインデントする
#
# dt (term), dd (definition)
#
# li は，中のブロック
# <ul> や <p> のように 実体のない (transparent) ブロックは，何もしない
# <li> のように，ぶら下げるブロックはインデントしない

module Kramdown
  module Converter

    # Converts a Kramdown::Document to ASCII Plain Text.
    #
    # You can customize this converter by sub-classing it and overriding the +convert_NAME+
    # methods. Each such method takes the following parameters:
    #
    # [+el+] The element of type +NAME+ to be converted.
    #
    # [+indent+] A number representing the current amount of spaces for indent (only used for
    #            block-level elements).
    #
    # The return value of such a method has to be a string containing the element +el+ formatted as
    # HTML element.
    class Ascii < Base

      MAX_COLUMN = 80

      include ::Kramdown::Utils::Html
      include ::Kramdown::Parser::Html::Constants

      # The amount of indentation used when nesting HTML tags.
      attr_accessor :indent

      # Initialize the ASCII converter with the given Kramdown document +doc+.
      def initialize(root, options)
        super
        @indent = 2
        @stack = []
        @xref_table = {}
        ref_visitor = ReferenceVisitor.new
        @root = ref_visitor.traverse(@root)
        @xref_table = ref_visitor.xref_table
        @item_table = ref_visitor.item_table
        @section_table = ref_visitor.section_table
        debug_dump_tree(@root) if $JAY_DEBUG
        @root
      end

      # Dispatch the conversion of the element +el+ to a +convert_TYPE+ method using the +type+ of
      # the element.
      def convert(el, indent = 0)
        send(DISPATCHER[el.type], el, indent)
      end

      # The mapping of element type to conversion method.
      DISPATCHER = Hash.new {|h,k| h[k] = "convert_#{k}"}

      ################################################################
      private

      # Format the given element as span text.
      def format_as_span(name, attr, body)
        return "<SPAN:#{name}>#{body}</SPAN:#{name}>" if $JAY_DEBUG
        return body.to_s.gsub(/\n */, "")
      end

      # indent を付加した span の列を作る
      # 前提として span 内には block はない
      # span は，行頭にある (block に直接内包される)か，改行を含むものしか indent されないので注意すること．
      def render_span(el, indent)
        el.children.each do |child|
          body << send(DISPATCHER[child.type], child, indent)
        end
        # XXX
      end

      # Format the given element as block text.
      # current_indent は自身のインデント幅で，ブロック内の
      #
      # render_block: block エレメントをレンダリングする．
      #
      # 前提: span の子供には span しか入っていない (block は，来ない)
      # span の子供が block になるような記述ができるのか不明 (tree をチェックして waring を出すほうがいいかも)
      #
      # 自分(block) について，子供に span があったら，つなげて indent する
      #
      # DISPATCHER を通して作った str は，indent だけのインデントを持つブロックを返すという前提
      # str = send(DISPATCHER[inner_el.type], inner_el, indent)
      def render_block(el, current_indent, add_indent = 0, bullet = nil)
        body = ""
        span = ""

        orig_indent = current_indent
        current_indent = [(add_indent + current_indent), 0].max

        el.children.each do |inner_el|
          str = send(DISPATCHER[inner_el.type], inner_el, current_indent)

          if el.ancestor?(:blockquote)
            body << str # no wrap
          elsif Element.category(inner_el) == :span
            span << str
          else
            # body << wrap_block(span, current_indent, 60) if span.length > 0
            body << span
            body << str
            span = ""
          end
        end
        if span.length > 0
          # body << wrap_block(span, current_indent, 60)
          body << span
          span = ""
        end

        body = add_bullet_to_block(bullet, body, orig_indent) if bullet
        body = add_indent_to_block(add_indent, body) if add_indent > 0
        # body = remove_indent(body, 2) if bullet && bullet.length > 2 && ancestor?(el, :li)
        body = body.sub(/[\s]*\Z/, "") + "\n"

        return "<BLOCK:#{el.type}>#{body}</BLOCK:#{el.type}>\n" if $JAY_DEBUG
        return "#{body}"
      end

      # XXX この中で span に indent を付けるのはおかしい
      #
      def wrap_block(body, indent, max_columns)
        # puts "WRAP_BLOCK: #{body}, #{indent}"
        body = remove_indent(body, indent)
        body = wrap(body, max_columns - indent)
        body = add_indent_to_block(indent, body)
        # puts "WRAPed_BLOCK: #{body}, #{indent}"
        body
      end

      def remove_indent(body, indent)
        body.gsub(/^#{" "*indent}/, "")
      end

      def wrap(body, width)
        body = body.gsub(/[\r\n]/, "")
        string, length = "", 0
        body.each_char.map do |c|
          string << c
          length += (c.bytesize == 1 ? 1 : 2)
          if length > width
            string << "\n"
            length = 0
          end
        end
        string
      end

      ################################################################
      # conver each element

      def convert_blank(el, indent)
        render_block(el, indent)
      end

      def convert_text(el, indent)
        format_as_span("text", nil, el.value)
      end

      def convert_p(el, indent)
        render_block(el, indent)
      end

      def convert_codeblock(el, indent)
        "-----------------------\n" + el.value.to_s + "-----------------------\n"
      end

      def convert_blockquote(el, indent)
        "-----------------------\n" + render_block(el, indent, 4) + "-----------------------"
      end

      def convert_header(el, indent)
        render_block(el, indent, 0, "#{el.value.full_mark}")
      end

      def convert_hr(el, indent)
        "-" * MAX_COLUMN
      end

      def convert_ul(el, indent)
        render_block(el, indent)
      end

      def convert_dl(el, indent)
        format_as_block("dl", nil, render_block(el, indent), indent)
      end

      def convert_li(el, indent)
        output = ''

        bullet = el.value ? "(#{el.value.mark})" : "*"

        output << "<BLOCK:li>" if $JAY_DEBUG
        output << render_block(el, indent, 0, bullet)
        output << "</BLOCK:li>" if $JAY_DEBUG
        output
      end

      def add_bullet_to_block(bullet, body, indent)
        hang = 0
        bullet_offset = " " * (bullet.size + 1)
        indent_string = " " * indent
        hang_string   = " " * hang

        body = body.sub(/^#{indent_string}/, "#{indent_string}#{bullet} ")
        body = body.gsub(/\n/, "\n" + bullet_offset)
        body = body.gsub(/^#{hang_string}/, "") if hang > 0
        body
      end

      def add_indent_to_block(indent, body)
        spc = " " * indent
        body = "#{spc}#{body}".gsub(/\n/, "\n" + spc)
      end

      def convert_dt(el, indent)
        render_block(el, indent)
      end

      def convert_html_element(el, indent)
        ""
      end

      def convert_xml_comment(el, indent)
        ""
      end

      def convert_table(el, indent)
        render_block(el, indent)
      end

      def convert_td(el, indent)
        render_block(el, indent)
      end

      def convert_comment(el, indent)
        render_block(el, indent)
      end

      def convert_br(el, indent)
        "\n" # "\n"
      end

      def convert_a(el, indent)
        if (c = el.children.first) && c.type == :text && c.value
          "[" + c.value + "]"
        else
          el.attr["href"].to_s
        end
      end

      def convert_img(el, indent)
        el.attr["href"].to_s
      end

      def convert_codespan(el, indent)
        "-----------------------\n" + el.value.to_s + "-----------------------"
      end

      def convert_footnote(el, indent)
        ""
      end

      def convert_raw(el, indent)
        el.value + (el.options[:category] == :block ? "\n" : '')
      end

      def convert_em(el, indent)
        format_as_span(el.type, el.attr, render_block(el, indent))
      end

      # ;gt
      def convert_entity(el, indent)
        format_as_span(el.type, el.attr, render_block(el, indent))
      end

      def convert_typographic_sym(el, indent)
        {
          :mdash => "---",
          :ndash => "--",
          :hellip => "...",
          :laquo_space => "<<",
          :raquo_space => ">>",
          :laquo => "<< ",
          :raquo => " >>",
        }[el.value]
      end

      def convert_smart_quote(el, indent)
        {
          :lsquo => "'",
          :rsquo => "'",
          :ldquo => '"',
          :rdquo => '"',
        }[el.value]
      end

      def convert_math(el, indent)
        format_as_span(el.type, el.attr, render_block(el, indent))
      end

      def convert_abbreviation(el, indent)
        title = @root.options[:abbrev_defs][el.value]
        attr = @root.options[:abbrev_attr][el.value].dup
        attr['title'] = title unless title.empty?
        format_as_span("abbr", attr, el.value)
      end

      def convert_root(el, indent)
        render_block(el, indent)
      end

      alias :convert_ol :convert_ul
      alias :convert_dd :convert_li
      alias :convert_xml_pi :convert_xml_comment
      alias :convert_thead :convert_table
      alias :convert_tbody :convert_table
      alias :convert_tfoot :convert_table
      alias :convert_tr  :convert_table
      alias :convert_strong :convert_em

      ################################################################

      def convert_ref(el, indent)
        if @xref_table[el.value]
          return "(#{@xref_table[el.value].full_mark})"
        elsif el.value =~ /^(\++|-+)$/
          parent = el.find_first_ancestor(:header) || el.find_first_ancestor(:li)
          table = parent.type == :li ? @item_table : @section_table
          rel_pos = ($1.include?("+") ? 1 : -1) * $1.length
          idx = parent.options[:relative_position] + rel_pos
          ref_el = idx >= 0 ? table[idx] : nil
          return "(#{ref_el.value.full_mark})" if ref_el
        end
        "(???)"
      end

      def convert_label(el, indent)
        ""
      end

      def convert_action_item(el, indent)
        "-->(#{el.options[:assignee]})"
      end

      def convert_issue_link(el, indent)
        el.options[:match]
      end

      def debug_dump_tree(tree, indent = 0)
        STDERR.print " " * indent
        STDERR.print "#{tree.type}(#{Element.category(tree)}) <<#{tree.value.to_s.gsub("\n", '\n')}>>\n"
        tree.children.each do |c|
          debug_dump_tree(c, indent + 2)
        end
      end

    end # class Ascii
  end # module Converter
end # module Kramdown
