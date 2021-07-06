require 'test_helper'
require_relative '../../lib/markdown_converter.rb'

class ArticleTest < ActiveSupport::TestCase

  #行頭に１つのスペースを含む項番なしリストのネストの入力が，ネストではない項番なしリストの出力になる問題を検証するテスト
  test "should get nesting of unordered list" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("* aaa\n * aaa").content == "* aaa\n    * aaa"
  end

  #文字列の下行の '-' の入力が，2段階見出しの出力になる問題を検証するテスト
  test "should get '-' below 'aaa'" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("aaa\n-").content == "aaa\n-"
  end

  #項番付きリストの下行の項番なしリストの入力が，項番付きリストの出力になる問題を検証するテスト
  test "should get unordered list below ordered list" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("+ aaa\n* aaa").content == "(1) aaa\n* aaa"
  end

  #項番なしリストの下行の項番付きリストの入力が，項番なしリストの出力になる問題を検証するテスト
  test "should get ordered list below unordered list" do
    assert JayFlavoredMarkdownToPlainTextConverter.new("* aaa\n+ aaa").content == "* aaa\n(1) aaa"
  end
end
