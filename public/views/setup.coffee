render=(r)->
  window.r=r
  console.log r
  template=($("#template")[0]).innerHTML
  hb=Handlebars.compile(template)
  results=hb(r)
  $("#placeholder").html(results)
  $("#placeholder").show()
  $("#ajax_button").show()



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

#Parse web page
#
# Returns JSON representation of input
parse_html=()->
  total_blocks=$("#total_blocks")[0].value
  total_GI=$("#total_GI")[0].value
  total_SO=$("#total_SO")[0].value
  total_ESD=$("#total_ESD")[0].value
  total_cytology=$("#total_cytology")[0].value
  data=
    path_present: _.union(get_checked("working"),get_unchecked("absent"))
    path_absent: _.union(get_checked("absent"),get_unchecked("working"))
    total_blocks: total_blocks
    total_GI: total_GI
    total_SO: total_SO
    total_ESD: total_ESD
    total_cytology: total_cytology
  return data
window.parse_html=parse_html


post_data=()->
  data=parse_html()
  window.data=data
  $.post("/setup", data,(e)->
    if JSON.parse(e)
      $.get("/get_setup",(e)->render JSON.parse(e))
      alert "Data Updated"
      #window.location.href="/setup"
      console.log(e))
window.post_data=post_data


$(document).ready =>
  $("#placeholder").hide()
  $.get("/get_setup",(e)->render JSON.parse(e))
  window.t=$("#template")
  window.p=$("#placeholder")
  window.render=render

  $("#ajax_button").click(
    (e)->
      post_data())











