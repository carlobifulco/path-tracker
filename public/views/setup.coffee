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

post_data=()->
  blocks_east=$("#blocks_east")[0].value
  blocks_west=$("#blocks_west")[0].value
  blocks_hr=$("#blocks_hr")[0].value
  data=
    path_present: _.union(get_checked("working"),get_unchecked("absent"))
    path_absent: _.union(get_checked("absent"),get_unchecked("working"))
    blocks_east: blocks_east
    blocks_west: blocks_west
    blocks_hr: blocks_hr
  window.data=data
  $.post("/setup", data,(e)->
    if JSON.parse(e)
      $.get("/get_setup",(e)->render JSON.parse(e))
      alert "Data Updated"
      #window.location.href="/setup"
      console.log(e))


$(document).ready =>
  $("#placeholder").hide()
  $.get("/get_setup",(e)->render JSON.parse(e))
  window.t=$("#template")
  window.p=$("#placeholder")
  window.render=render

  $("#ajax_button").click(
    (e)->
      post_data())
  window.post_data=post_data










