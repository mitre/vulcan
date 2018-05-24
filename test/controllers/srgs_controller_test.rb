require 'test_helper'

class SrgsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @srg = srgs(:one)
  end

  test "should get index" do
    get srgs_url
    assert_response :success
  end

  test "should get new" do
    get new_srg_url
    assert_response :success
  end

  test "should create srg" do
    assert_difference('Srg.count') do
      post srgs_url, params: { srg: {  } }
    end

    assert_redirected_to srg_url(Srg.last)
  end

  test "should show srg" do
    get srg_url(@srg)
    assert_response :success
  end

  test "should get edit" do
    get edit_srg_url(@srg)
    assert_response :success
  end

  test "should update srg" do
    patch srg_url(@srg), params: { srg: {  } }
    assert_redirected_to srg_url(@srg)
  end

  test "should destroy srg" do
    assert_difference('Srg.count', -1) do
      delete srg_url(@srg)
    end

    assert_redirected_to srgs_url
  end
end
