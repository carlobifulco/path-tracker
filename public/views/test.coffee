render=(data,html)->
  if typeof(data)=="string"
    data=JSON.parse(data); console.log data
  hb=Handlebars.compile(html)
  results=hb(data)
  return results
window.render=render



cardinal=()->
  $.get("/activities_cardinal", (data)->
    window.cardinal_data=data
    window.cardinal_html=($("#cardinal_template")[0]).innerHTML
    )
window.cardinal=cardinal


regular=()->
  $.get("/activities_regular", (data)->
    window.regular_data=data
    window.regular_html=($("#regular_template")[0]).innerHTML
    )
window.regular=regular

show=(name)->
  $("#cardinal_html").html(render(window.cardinal_data,window.cardinal_html))
window.show_cardinal =show_cardinal

show_regular=()->
  $("#regular_html").html(render(window.regular_data,window.regular_html))
window.show_regular =show_regular


$(document).ready =>
  console.log "I am loaded"
  $.when(cardinal()).then(show_cardinal)
  $.when(regular()).then(show_regular)

  #cardinal()



