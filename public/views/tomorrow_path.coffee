window.get_checked=get_checked=(id)->
  checked_boxes=$("##{id} input[type='checkbox']:checked")
  $(i).attr("name") for i in checked_boxes
window.get_checked=get_checked

window.get_all=get_all=(id)->
  all_boxes=$("##{id} input[type='checkbox']")
  $(i).attr("name") for i in all_boxes
window.get_all=get_all

window.get_unchecked=get_unchecked=(id)->
  i for i in get_all(id) when i not in get_checked(id)
window.get_unchecked=get_unchecked

#Parse web page
#
# Returns JSON representation of input
window.parse_html=parse_html=()->

  data=
    path_present: _.union(get_checked("working"),get_unchecked("absent"))
    path_absent: _.union(get_checked("absent"),get_unchecked("working"))





#### HB rendering
render=(data,html)->
  if typeof(data)=="string"
    data=JSON.parse(data); console.log data
  hb=Handlebars.compile(html)
  results=hb(data)
  return results
window.render=render


#wrapper around the rendering; uses the html target convention "id_html" and "id_template"
render_template=(id,data)->
  rendered_template=render(data,($("##{id}_template")[0]).innerHTML)
  console.log rendered_template
  hook= $("##{id}_html")
  if hook.length==0 then console.log "NO HOOCK"
  $("##{id}_html").html(rendered_template)
window.render_template=render_template


post_data=()->
  data=parse_html()
  window.data=data
  $.post("/setup/1", data,(e)->
    if JSON.parse(e)
      show_paths()
      alert "Data Updated"
      #window.location.href="/setup"
      console.log(e))
window.post_data=post_data





window.show_paths=show_paths=()->
   $.get("/get_setup/1",(e)->
    window.data=data=JSON.parse(e)
    window.working=working={pathologist_working: data.pathologist_working}
    render_template("working", working)
    window.absent=absent={pathologist_absent: data.pathologist_absent}
    render_template("absent",absent)

    )


$(document).ready =>
  console.log "here I am"
  show_paths()
  $("#ajax_button").click((e)->
    console.log "click"
    post_data())