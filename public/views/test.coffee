ws_url='ws://localhost:4567/test'
window.ws_url=ws_url



#### HB rendering
render=(data,html)->
  if typeof(data)=="string"
    data=JSON.parse(data); console.log data
  hb=Handlebars.compile(html)
  results=hb(data)
  return results
window.render=render


render_template=(id,data)->
  $("##{id}_html").html(render(data,($("##{id}_template")[0]).innerHTML))
window.render_template=render_template

onclose=()->
  console.log "a new socket is being made dude..."
  window.s=new WebSocket(ws_url)
  window.s.onclose=onclose
  window.s.onmessage=onmessage
  window.s.onclose=onclose

onmessage=(m)->
  console.log m.data

onopen=()->
  console.log "We are open my dear dude"


    # window.onload = function(){
    #   (function(){
    #     var show = function(el){
    #       return function(msg){ el.innerHTML = msg + '<br />' + el.innerHTML; }
    #     }(document.getElementById('msgs'));

    #     var ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
    #     ws.onopen    = function()  { show('websocket opened'); };
    #     ws.onclose   = function()  { show('websocket closed'); }
    #     ws.onmessage = function(m) { show('websocket message: ' +  m.data); };

    #     var sender = function(f){
    #       var input     = document.getElementById('input');
    #       input.onclick = function(){ input.value = "" };
    #       f.onsubmit    = function(){
    #         ws.send(input.value);
    #         input.value = "send a message";
    #         return false;
    #       }
    #     }(document.getElementById('form'));
    #   })();
    # }

$(document).ready =>
    console.log "I am loaded; USE show(id) to update entry"
    window.s=new WebSocket(ws_url)
    window.s.onclose=onclose
    window.s.onmessage=onmessage
    window.s.onclose=onclose




