render=(r="")->
  window.r=r
  console.log r
  template=($("#template")[0]).innerHTML
  hb=Handlebars.compile(template)
  results=hb(r)
  $("#placeholder").html(results)
  $("#placeholder").show()




$(document).ready =>
  $("#placeholder").hide()
  #$.get("/get_setup",(e)->render JSON.parse(e))
  window.t=$("#template")
  window.p=$("#placeholder")
  window.render=render
  $.get("/get_entry",(e)->render(e))