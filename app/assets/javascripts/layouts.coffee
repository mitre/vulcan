ready = ->
  jQuery ->
    $('#sidebarCollapse').on('click', toggle)
    
toggle = ->
  jQuery ->
    $('#sidebar').toggleClass('active');

$(document).ready(ready)
$(document).on('page:load', ready)