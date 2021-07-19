require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    OmniAuth.config.test_mode = true
  end

  test "should get index" do
    log_in_as(@user)
    get users_url
    assert_response :success
  end

  test "should show user" do
    log_in_as(@user)
    get user_url(@user)
    assert_response :success
  end

  test "should get edit" do
    log_in_as(@user)
    get edit_user_url(@user)
    assert_response :success
  end

  test "should update user" do
    log_in_as(@user)
    patch user_url(@user), params: { user: { screen_name: @user.screen_name, name: @user.name } }
    assert_response :success
  end

end
