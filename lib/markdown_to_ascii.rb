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
        @root = make_xref(@root)
      end

      # Dispatch the conversion of the element +el+ to a +convert_TYPE+ method using the +type+ of
      # the element.
      def convert(el, indent = -@indent)
        send(DISPATCHER[el.type], el, indent)
      end

      # The mapping of element type to conversion method.
      DISPATCHER = Hash.new {|h,k| h[k] = "convert_#{k}"}

      ################################################################
      private

      # Return the converted content of the children of +el+ as a string. The parameter +indent+ has
      # to be the amount of indentation used for the element +el+.
      #
      # Pushes +el+ onto the @stack before converting the child elements and pops it from the stack
      # afterwards.
      def inner(el, indent)
        result = ""
        indent += @indent
        @stack.push(el)
        el.children.each do |inner_el|
          result << send(DISPATCHER[inner_el.type], inner_el, indent)
        end
        @stack.pop
        result
      end

      # Format the given element as span text.
      def format_as_span(name, attr, body)
        body.to_s
      end

      # Format the given element as block text.
      def format_as_block(name, attr, body, indent)
        "#{' '*indent}<#{name}#{html_attributes(attr)}>#{body}</#{name}>\n"
      end

      # Format the given element as block text with a newline after the start tag and indentation
      # before the end tag.
      def format_as_indented_block(name, attr, body, indent)
        "#{' '*indent}<#{name}#{html_attributes(attr)}>\n#{body}#{' '*indent}</#{name}>\n"
      end

      ################################################################
      # conver each element
      def convert_blank(el, indent)
        "\n"
      end

      def convert_text(el, indent)
        el.value
      end

      def convert_p(el, indent)
        inner(el, indent)
      end

      def convert_codeblock(el, indent)
        inner(el, indent)
      end

      def convert_blockquote(el, indent)
        inner(el, indent)
      end

      def convert_header(el, indent)
        "= " + inner(el, indent) + "\n"
      end

      def convert_hr(el, indent)
        "-" * MAX_COLUMN
      end

      def convert_ul(el, indent)
        inner(el, indent)
      end

      def convert_dl(el, indent)
        inner(el, indent)
      end

      def convert_li(el, indent)
        output = ''
        if el.value
          # 本来は，こちらで動かさないといけない．HTML の Converter の convert_li に bullet を入れるべき
          # output = ' '*indent << "(#{el.value.mark})" << inner(el, indent) << "\n"
          output = ' '*indent << inner(el, indent) << "\n"
        else
          output = ' '*indent << "* " << inner(el, indent) << "\n"
        end
      end

      def convert_dt(el, indent)
        inner(el, indent)
      end

      def convert_html_element(el, indent)
        ""
      end

      def convert_xml_comment(el, indent)
        ""
      end

      def convert_table(el, indent)
        inner(el, indent)
      end

      def convert_td(el, indent)
        inner(el, indent)
      end

      def convert_comment(el, indent)
        inner(el, indent)
      end

      def convert_br(el, indent)
        "" # "\n"
      end

      def convert_a(el, indent)
        el.attr["href"].to_s
      end

      def convert_img(el, indent)
        el.attr["href"].to_s
      end

      def convert_codespan(el, indent)
        format_as_span(el.value)
      end

      def convert_footnote(el, indent)
        ""
      end

      def convert_raw(el, indent)
        el.value + (el.options[:category] == :block ? "\n" : '')
      end

      def convert_em(el, indent)
        format_as_span(el.type, el.attr, inner(el, indent))
      end

      # ;gt
      def convert_entity(el, indent)
        format_as_span(el.type, el.attr, inner(el, indent))
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
        format_as_span(el.type, el.attr, inner(el, indent))
      end

      def convert_abbreviation(el, indent)
        title = @root.options[:abbrev_defs][el.value]
        attr = @root.options[:abbrev_attr][el.value].dup
        attr['title'] = title unless title.empty?
        format_as_span("abbr", attr, el.value)
      end

      def convert_root(el, indent)
        inner(el, indent)
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
          "(#{@xref_table[el.value].full_mark})"
        else
          "(???)"
        end
      end

      def convert_label(el, indent)
        ""
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

    end # class Ascii
  end # module Converter
end # module Kramdown
