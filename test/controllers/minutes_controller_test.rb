require "test_helper"

class MinutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @minute = minutes(:one)
    OmniAuth.config.test_mode = true
  end

  test "should get index" do
    log_in_as(@user)
    get minutes_url
    assert_response :success
  end

  test "should get new" do
    log_in_as(@user)
    get new_minute_url
    assert_response :success
  end

  test "should create minute" do
    log_in_as(@user)
    post minutes_url, params: {
      minute: {
        id: @minute.id,
        title: @minute.title,
        dtstart: @minute.dtstart,
        dtend: @minute.dtend,
        location: @minute.location,
        author_id: @minute.author_id,
        content: @minute.content
      }
    }
    assert_redirected_to minute_url(@minute.id + 1)
  end

  test "should show minute" do
    log_in_as(@user)
    get minute_url(@minute)
    assert_response :success
  end

  test "should get edit" do
    log_in_as(@user)
    get edit_minute_url(@minute)
    assert_response :success
  end

  test "should update minute" do
    log_in_as(@user)
    patch minute_url(@minute), params: {
      minute: {
        title: @minute.title,
        dtstart: @minute.dtstart,
        dtend: @minute.dtend,
        location: @minute.location,
        author_id: @minute.author_id,
        content: @minute.content
      }
    }
    assert_redirected_to minute_url(@minute)
  end

  test "should delete minute" do
    log_in_as(@user)
    delete minute_url(@minute)
    assert_redirected_to minutes_url
  end

end
