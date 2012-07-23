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
    #show button
    $("#serialize").show() if func
    $("#serialize").click(()->serialize()) if func
    ) 

window.show_sparklines=show_sparklines


###### Get cardinal activities, will be defereed
show_cardinal=()->
  $.get("/activities_cardinal", (data)->
    window.cardinal_data=JSON.parse data
    render_template("cardinal", data)
    )
window.show_cardinal=show_cardinal

###### as above
show_regular=()->
  $.get("/activities_regular", (data)->
    data=JSON.parse data
    render_template "regular", data)
window.show_regular=show_regular

#### updated input, both checkbox and numeric
update=(id,n)->
  activity=$("##{id}")
  console.log activity
  if activity.attr("type")=="checkbox" then activity.attr("checked",true)
  if activity.attr("type")=="text" then activity.val(n)
window.update=update


  


# updates points for specific id initials
show=(id)->
  window.id=id
  render_template("id",({id: id} ))
  #render cardinal template
  show_cardinal()
  #render regular template
  show_regular()
  #update all data
  $.get("/path/activities/points",(data)=>
    data=JSON.parse(data)
    activities=data["path"]["#{id}"]
    update(i,activities[i].n) for i in _.keys(activities))
  #update all  sparklines
  show_sparklines(()->$("##{id}").css("color", "red"))
  #$(".show_entry").css("color", "")


#serialize and call post /entry
serialize=()->
  data=$("#entry").serializeArray()
  console.log data
  window.data=data
  $.post("/entry",$("#entry").serializeArray(), (e)->
    if JSON.parse(e)["ok"]
      alert "Data updated"
      show_sparklines(()->$("##{$("#path_name").val()}").css("color", "red"))
  )

window.serialize=serialize

  



window.show=show


$(document).ready =>
  console.log "here I am"
  #show_cardinal()
  #show_regular()
  show_sparklines()

