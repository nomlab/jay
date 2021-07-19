require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @tag = tags(:one)
    OmniAuth.config.test_mode = true
  end

  test "should get index" do
    log_in_as(@user)
    get tags_url
    assert_response :success
  end


  test "should get new" do
    log_in_as(@user)
    get new_minute_url
    assert_response :success
  end

  test "should create tag" do
    log_in_as(@user)
    post tags_url, params: { tag: { name: @tag.name } }
    assert_response :success
  end

  test "should show tag" do
    log_in_as(@user)
    get tag_url(@tag)
    assert_response :success
  end

  test "should get edit" do
    log_in_as(@user)
    get edit_tag_url(@tag)
    assert_response :success
  end

  test "should update tag" do
    log_in_as(@user)
    patch tag_url(@tag), params: { tag: { name: @tag.name } }
    assert_response :success
  end

  test "should delete tag" do
    log_in_as(@user)
    delete tag_url(@tag)
    assert_redirected_to tags_url
  end

end
