require 'test_helper'
require_relative '../../lib/markdown_converter.rb'

class ArticleTest < ActiveSupport::TestCase
  # test "sample" do
  #   assert true
  # end
  # プレーンテキストのインデントは，半角スペース4つ

  test "space of unordered list" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("* aaa\n * aaa").content == "* aaa\n    * aaa"
  end

  test "header2" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("aaa\n-").content == "aaa\n-"
  end

  test "folding in writing" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("").content == ""
  end

  test "unordered list after ordered list" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("+ aaa\n* aaa").content == "(1) aaa\n* aaa"
  end

  test "ordered list after unordered list" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("* aaa\n+ aaa").content == "* aaa\n(1) aaa"
  end

  test "secondary unordered list after ordered list" do # ビュレットが食い込む問題は，プレーンテキストレベルではわからない
    assert JayFlavoredMarkdownToPlainTextConverter.new("+ aaa\n  * aaa").content == "(1) aaa\n    * aaa"
  end
end
