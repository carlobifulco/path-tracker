

#### HB rendering
render=(data,html)->
  if typeof(data)=="string"
    data=JSON.parse(data); console.log data
  hb=Handlebars.compile(html)
  results=hb(data)
  return results
window.render=render



#wrapper around the rendering; uses the html target convention "id_html"
render_template=(id,data)->
  $("##{id}_html").html(render(data,($("##{id}_template")[0]).innerHTML))
window.render_template=render_template


show_sparklines=(func=false)->
  $.get("/get_dashboard",(data)=>
    data=JSON.parse(data)
    window.data=data
    for key in _.keys(data)
      do (key)->
        render_template("sparkline",data)
        #show sparklines
        $('.inlinesparkline').sparkline("html", {type: "line",width: '300px' , height: "35px"})
    #bind click
    # reddens the selected id
    func() if func
    ) 

window.show_sparklines=show_sparklines





$(document).ready =>
  console.log "here I am"
  #show_cardinal()
  #show_regular()
  show_sparklines()