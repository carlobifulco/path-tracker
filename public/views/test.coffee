
#### HB rendering
render=(data,html)->
  if typeof(data)=="string"
    data=JSON.parse(data); console.log data
  hb=Handlebars.compile(html)
  results=hb(data)
  return results
window.render=render


###### Get cardinal activities, will be defereed
cardinal=()->
  $.get("/activities_cardinal", (data)->
    window.cardinal_data=data
    window.cardinal_html=($("#cardinal_template")[0]).innerHTML
    )
window.cardinal=cardinal

###### Finds plceholder and replaces it with data
show_cardinal=(name)->
  $("#cardinal_html").html(render(window.cardinal_data,window.cardinal_html))
window.show_cardinal =show_cardinal

###### as above
regular=()->
  $.get("/activities_regular", (data)->
    window.regular_data=data
    window.regular_html=($("#regular_template")[0]).innerHTML
    )
window.regular=regular

###### as above
show_regular=()->
  $("#regular_html").html(render(window.regular_data,window.regular_html))
window.show_regular =show_regular




#### updated input, both checkbox and numeric
update=(id,n)->
  activity=$("##{id}")
  console.log activity
  if activity.attr("type")=="checkbox" then activity.attr("checked",true)
  if activity.attr("type")=="text" then activity.val(n)
window.update=update




#### gets /path/activities/points
activities=()=>
  dfd = $.Deferred()
  $.get("/path/activities/points",(data)=>
    data=JSON.parse(data)
    console.log data
    window.path_act_points=data
    dfd.resolve()
    )
  return dfd.promise()
window.activities=activities


render_template=(id,data)->
  $("##{id}_html").html(render(data,($("##{id}_template")[0]).innerHTML))
window.render_template=render_template

show=(id)->
  window.id=id
  $("#id_html").html(render({id: id},($("#id_template")[0]).innerHTML))
  $.when(cardinal()).then(show_cardinal)
  $.when(regular()).then(show_regular)
  $.get("/path/activities/points",(data)=>
    data=JSON.parse(data)
    activities=data["path"]["#{id}"]
    update(i,activities[i].n) for i in _.keys(activities))
window.show=show


$(document).ready =>
  window.path_act_points={}
  console.log "I am loaded; USE show(id) to update entry"
  # $.when(cardinal()).then(show_cardinal)
  # $.when(regular()).then(show_regular)

  # $.when(activities()).done(()=>
  #   $.when(working()).done(()=>
  #     show_activities(i) for i in  window.path_working))
  # console.log "cbb"

  #cardinal()


# show_activities=(id)->

#   activities=window.path_act_points["path"]["#{id}"]
#   update(i,activities[i].n) for i in _.keys(activities)
# window.show_activities=show_activities


# working=()=>
#   dfd = $.Deferred()
#   $.get("/path/working",(data)=>
#     window.path_working=JSON.parse(data)
#     dfd.resolve()
#     )
#   return dfd.promise()
# window.working=working


