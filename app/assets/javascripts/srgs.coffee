# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
ready = ->
  jQuery ->
    $('#srg-search').on('input', search_srg)
    $('#srg-filtering').footable().on('footable_filtering', filter_srg)
    $('#srg-controls-search').on('input', search_srg_control)
    $('#srg-controls-datatable').footable().on('footable_filtering', filter_srg_control)

# Filtering
# ----------------------------------------------------------------
filter_srg = (e) ->
  jQuery ->
    e.filter += (e.filter && e.filter.length > 0) ?
    e.clear = !e.filter

# Search input
search_srg = (e) ->
  jQuery ->
    e.preventDefault()
    $('#srg-filtering').trigger('footable_filter', {filter: $('#srg-search').val()})
    
# Filtering
# ----------------------------------------------------------------
filter_srg_control = (e) ->
  jQuery ->
    e.filter += (e.filter && e.filter.length > 0) ?
    e.clear = !e.filter

# Search input
search_srg_control = (e) ->
  jQuery ->
    e.preventDefault()
    $('#srg-controls-datatable').trigger('footable_filter', {filter: $('#srg-controls-search').val()})

$(document).ready(ready)
$(document).on('turbolinks:load', ready)
