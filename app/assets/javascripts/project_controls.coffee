ready = ->
  jQuery ->
    $('[name="project_control[applicability]"]').on("change", add_fields)
    $('#srg_pop').popover()
    $(".pagination").rPage();
    

add_fields = ->
  jQuery ->
    if $('[name="project_control[applicability]"]').val() == 'Applicable - Does Not Meet'
      $('#checktext_fields').show()
      $('#main_control_fields').hide()
      $('#justification_field').hide()
      $('#fixtext_fields').hide()
    if $('[name="project_control[applicability]"]').val() == 'Applicable - Configurable'
      $('#justification_field').hide()
      $('#main_control_fields').show()
      $('#checktext_fields').show()
      $('#fixtext_fields').show()
    if $('[name="project_control[applicability]"]').val() == 'Applicable - Inherently Meets' || $('#project_control_applicability').val() == 'Not Applicable'
      $('#justification_field').show()
      $('#main_control_fields').hide()
      $('#checktext_fields').hide()
      $('#fixtext_fields').hide()

$(document).ready(ready)
$(document).ready(add_fields)
$(document).on('turbolinks:load', ready)