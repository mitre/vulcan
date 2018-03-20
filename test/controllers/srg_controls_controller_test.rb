require 'test_helper'

class SrgControlsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @srg_control = srg_controls(:one)
  end

  test "should get index" do
    get srg_controls_url
    assert_response :success
  end

  test "should get new" do
    get new_srg_control_url
    assert_response :success
  end

  test "should create srg_control" do
    assert_difference('SrgControl.count') do
      post srg_controls_url, params: { srg_control: { checkid: @srg_control.checkid, checktext: @srg_control.checktext, controlId: @srg_control.controlId, description: @srg_control.description, fixid: @srg_control.fixid, fixtext: @srg_control.fixtext, iacontrols: @srg_control.iacontrols, ruleID: @srg_control.ruleID, severity: @srg_control.severity, title: @srg_control.title } }
    end

    assert_redirected_to srg_control_url(SrgControl.last)
  end

  test "should show srg_control" do
    get srg_control_url(@srg_control)
    assert_response :success
  end

  test "should get edit" do
    get edit_srg_control_url(@srg_control)
    assert_response :success
  end

  test "should update srg_control" do
    patch srg_control_url(@srg_control), params: { srg_control: { checkid: @srg_control.checkid, checktext: @srg_control.checktext, controlId: @srg_control.controlId, description: @srg_control.description, fixid: @srg_control.fixid, fixtext: @srg_control.fixtext, iacontrols: @srg_control.iacontrols, ruleID: @srg_control.ruleID, severity: @srg_control.severity, title: @srg_control.title } }
    assert_redirected_to srg_control_url(@srg_control)
  end

  test "should destroy srg_control" do
    assert_difference('SrgControl.count', -1) do
      delete srg_control_url(@srg_control)
    end

    assert_redirected_to srg_controls_url
  end
end
