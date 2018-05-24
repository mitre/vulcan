ready = ->
  jQuery ->
    $('[name="project_control[status]"]').on("change", add_fields)

add_fields = ->
  jQuery ->
    if $('[name="project_control[status]"]').val() == 'Applicable - Does Not Meet'
      $('#checktext_fields').show()
      $('#main_control_fields').hide()
      $('#justification_field').hide()
      $('#fixtext_fields').hide()
    if $('[name="project_control[status]"]').val() == 'Applicable - Configurable'
      $('#justification_field').hide()
      $('#main_control_fields').show()
      $('#checktext_fields').show()
      $('#fixtext_fields').show()
    if $('[name="project_control[status]"]').val() == 'Applicable - Inherently Meets' || $('#project_control_status').val() == 'Not Applicable'
      $('#justification_field').show()
      $('#main_control_fields').hide()
      $('#checktext_fields').hide()
      $('#fixtext_fields').hide()

$(document).ready(ready)
$(document).ready(add_fields)
$(document).on('turbolinks:load', ready)