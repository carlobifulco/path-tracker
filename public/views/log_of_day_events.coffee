$("#get_data").click(()->
  get_data())



get_data=(e=false)=>
  ini=$("#ini").val()
  console.log ini
  $.get("/log/#{ini}", (data)=>
    console.log "getting"
    console.log data
    window.data=data
    $("#log_html").html(data)
  )
window.get_data=get_data




$(document).ready =>
  console.log "here I am"
  KeyboardJS.bind.key("enter",get_data)