#pulls yaml data once per page early on
update_yaml=()->
    $.get("/get_yaml", (data)=>
      data= JSON.parse data
      console.log "getting"
      console.log data
      window.yaml=data
      )
window.update_yaml=update_yaml

update_yaml() unless window.yaml

#decorate with icons according to the pathologist's site
icons=()->
  for i in yaml.b_psv
    do (i)->
        $("##{i}").prepend($('<i class="icon-forward"></i>'))
  for i in yaml.c_ppmc
    do (i)->
        $("##{i}").prepend($('<i class="icon-play"></i>'))
  for i in yaml.d_core
    do (i)->
        $("##{i}").prepend($('<i class="icon-home"></i>'))
  for i in yaml.a_hr
    do (i)->
        $("##{i}").prepend($('<i class="icon-picture"></i>'))


#####checking of present absent

get_checked=(id)->
  checked_boxes=$("##{id} input[type='checkbox']:checked")
  $(i).attr("name") for i in checked_boxes
window.get_checked=get_checked

get_all=(id)->
  all_boxes=$("##{id} input[type='checkbox']")
  $(i).attr("name") for i in all_boxes
window.get_all=get_all

get_unchecked=(id)->
  i for i in get_all(id) when i not in get_checked(id)
window.get_unchecked=get_unchecked

get_path_status=()->
  data=
    path_present: _.union(get_checked("working"),get_unchecked("absent"))
    path_absent: _.union(get_checked("absent"),get_unchecked("working"))



#### HB rendering
render=(data,html)->
  if typeof(data)=="string"
    data=JSON.parse(data)
    #console.log data
  hb=Handlebars.compile(html)
  results=hb(data)
  return results
window.render=render

decorate=()->
  for ini in _.keys(data["paths_acts_points"])
    do (ini)->
      a=has_a_specialty(get_activities(ini))
      if a
        #console.log "#{ini} has specialty #{a}"
        $("##{ini}").parent().parent().addClass("error")
    do (ini)->
      a=has_a_location(get_activities(ini))
      if a
        #console.log "#{ini} has location #{a}"
        $("##{ini}").parent().parent().addClass("warning")
    do (ini)->
      a=has_a_distribution_preference(get_activities(ini))
      if a
        #console.log "#{ini} has location #{a}"
        $("##{ini}").parent().parent().addClass("success")

  icons()

make_hb=(match)->
  hb=Handlebars.compile(match[0].innerHTML)
window.make_hb=make_hb






window.decorate=decorate

#match activities of pathologist with special categories defined in the yaml file

get_activities=(ini)->
  _.keys(data["paths_acts_points"][ini])
window.get_activities=get_activities

has_a_specialty=(arr)->
  specialties=_.keys yaml["distribution-specialty"]
  match= _.intersection(arr,specialties)
  if match.length==1
    return match[0]
  else
    return false
window.has_a_specialty=has_a_specialty

has_a_location=(arr)->
  locations=_.keys yaml["distribution-location"]
  match= _.intersection(arr,locations)
  if match.length==1
    return match[0]
  else
    return false
window.has_a_location=has_a_location


has_a_distribution_preference=(arr)->
  specialties=_.keys yaml["distribution-preference"]
  match= _.intersection(arr,specialties)
  if match.length==1
    return match[0]
  else
    return false
window.has_a_distribution_preference=has_a_distribution_preference




#wrapper around the rendering; uses the html target convention "id_html" and "id_template"
render_template=(id,data)->
  rendered_template=render(data,($("##{id}_template")[0]).innerHTML)
  #console.log rendered_template
  hook= $("##{id}_html")
  if hook.length==0 then console.log "NO HOOCK"
  $("##{id}_html").html(rendered_template)
window.render_template=render_template

show_sparklines=(func=false)->
  $.get("/get_tomorrow",(data)=>
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
    decorate()
    render_template("status",data)
    )

window.show_sparklines=show_sparklines



###### Get cardinal activities, will be defereed
show_cardinal=()->
  $.get("/activities_cardinal", (data)->
    window.cardinal_data=JSON.parse data
    render_template("cardinal", data)
    checkbox_click()
    )
window.show_cardinal=show_cardinal

###### as above
show_regular=()->
  $.get("/activities_regular", (data)->
    data=JSON.parse data
    render_template "regular", data
    # bind click to data entry
    entry_click()
  )


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
  $.get("/path/activities/points/tomorrow",(data)=>
    data=JSON.parse(data)
    activities=data["path"]["#{id}"]
    update(i,activities[i].n) for i in _.keys(activities))
  #update all  sparklines
  show_sparklines(()->$("##{id}").css("color", "red"))
  #$(".show_entry").css("color", "")




#serialize and call post /entry
serialize=()->
  #console.log window.working
  #blocks submission in screen update is not finished
  if window.working==true
    return 
  data=$("#entry").serializeArray()
  all_values=$("input:text")
  checked=[i.name for i in $("input:checked")]
  console.log "checked before submission: #{checked}"
  #console.log data
  window.data=data
  console.log data
  log_activities $("#path_name").val(), {checked_before_submisstion: "#{checked}"}
  window.data=data
  $.post("/tomorrow",data, (e)->
    if JSON.parse(e)["ok"]
      alert "Data updated"
      show_sparklines(()->$("##{$("#path_name").val()}").css("color", "red"))
  )

window.serialize=serialize

#activate prompt on entry
entry_click=()->
  $('[type=text]').click((e)->
    console.log e
    if e.target
      
      console.log "e scrElement: #{e.target.value}" 
      e.target.value=Number(e.target.value)+Number(prompt("Add:"))

      #console.log e
      #console.log input_base
      )

window.entry_click=entry_click


checkbox_click=()->
   $('[type=checkbox]').click((e)->
      #console.log e
      #console.log "#{window.id}; #{e.currentTarget.id}: #{e.currentTarget.checked}"
      data=
        path_name: window.id
        tomorrow :"tomorrow"
        click: "#{e.currentTarget.id}: #{e.currentTarget.checked}"
      $.post("/entry_click_log", data, (e)->
        console.log "Post of click returned:#{e}")
      )
window.checkbox_click=checkbox_click

####logging of activities updates
log_activities=(id,activities={test:"OK"})->
  payload=
    id: id
    activities: activities or "None"
    tomorrow: "tomorrow"
  $.post('/activity_update_log',payload, (e)->
    console.log e)
window.log_activities=log_activities




window.show=show


$(document).ready =>
  console.log "here I am, again"
  #show_cardinal()
  #show_regular()
  show_sparklines()
  KeyboardJS.bind.key("enter",serialize)



