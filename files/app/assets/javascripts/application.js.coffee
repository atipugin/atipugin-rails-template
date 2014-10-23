#= require jquery_ujs

$ ->
  $('body').on 'click', 'a', (event) ->
    if @.getAttribute('href') == '#'
      event.preventDefault()
