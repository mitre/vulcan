# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
ready = ->
  jQuery ->
    $('#projects-search').on('input', search_projects)
    $('#projects-datatable').footable().on('footable_filtering', filter_projects)
    $('#pending-projects-search').on('input', search_pending_projects)
    $('#pending-projects-datatable').footable().on('footable_filtering', filter_pending_projects)
    $('#project-controls-search').on('input', search_project_controls)
    $('#project-controls-datatable').footable().on('footable_filtering', filter_project_controls)
    $('#awaiting-approval-datatable').footable()
    $('#requested-changes-datatable').footable()
    $('[name="project_control[status]"]').on("change", add_fields)
    $(".pagination").rPage()
    $('#project-controls-filter-applicability').on('change', filter_applicability)

add_fields = ->
  jQuery ->
    alert("jere");
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

# Filtering
# ----------------------------------------------------------------
filter_projects = (e) ->
  jQuery ->
    e.filter += (e.filter && e.filter.length > 0) ?
    e.clear = !e.filter

filter_pending_projects = (e) ->
  jQuery ->
    e.filter += (e.filter && e.filter.length > 0) ?
    e.clear = !e.filter

# Search input
search_projects = (e) ->
  jQuery ->
    e.preventDefault()
    $('#projects-datatable').trigger('footable_filter', {filter: $('#projects-search').val()})
    
# Search input
search_pending_projects = (e) ->
  jQuery ->
    e.preventDefault()
    $('#pending-projects-datatable').trigger('footable_filter', {filter: $('#pending-projects-search').val()})


filter_applicability = (e) ->
  jQuery ->
    e.preventDefault()
    $('#project-controls-datatable').trigger('footable_filter', {filter: $('#project-controls-filter-applicability').val()})
    
# Filtering
# ----------------------------------------------------------------
filter_project_controls = (e) ->
  jQuery ->
    e.filter += (e.filter && e.filter.length > 0) ?
    e.clear = !e.filter

# Search input
search_project_controls = (e) ->
  jQuery ->
    e.preventDefault()
    $('#project-controls-datatable').trigger('footable_filter', {filter: $('#project-controls-search').val()})

$(document).on('turbolinks:load', ready)
