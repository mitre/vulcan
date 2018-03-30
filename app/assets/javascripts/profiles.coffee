# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

ready = ->
  jQuery ->
    $('#profile_controls_datatable').DataTable()
    $('#profiles_datatable').DataTable()
  
$(document).ready(ready)
$(document).on('page:load', ready)
