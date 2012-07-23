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
  $.get("/get_entry",(data)=>
    data=JSON.parse(data)
    window.data=data
    render_template("sparkline",data)
    #show sparklines
    $('.inlinesparkline').sparkline("html", {type: "bullet",width: '30px' })
    #bind click
    $(".show_entry").click((e)=>console.log  e.currentTarget.id; show( e.currentTarget.id))
    # reddens the selected id
    func() if func
    ) 

window.show_sparklines=show_sparklines









$(document).ready =>
  console.log "here I am"
  #show_cardinal()
  #show_regular()
  show_sparklines()