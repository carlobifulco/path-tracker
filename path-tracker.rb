#libs for the generation of the DOT Files
#add the current dir  and lib to the load path
my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory



require "configuration"
# in
require "web_data"


#require "bundler/setup"
require 'coffee-script'
require "sinatra"
require 'sinatra-websocket'
require "report_svg"



set :server, 'thin'
set :sockets, []


set :username,'Bond'
set :token,'shakenN0tstirr3d'
set :password,'007'



####SINATRA SETUPS
set :root, File.dirname(__FILE__)

####decides if testing or production based on working directory
#Testing unless prduction
case File.basename(my_directory)
  when "path-tracker-deploy"
    puts "I am deploying production"
    switch_to_production
  when "path-tracker"
    puts "I am deployng testing"
    switch_to_testing
end




# Keeping coffee, compiled JS and html5 in the same directory
set :views, Proc.new { File.join(root, "public/views") }
enable :sessions


####helpers
#These have access to the params in  sinatra get/post funtions
helpers do
  def admin? ; request.cookies[settings.username] == settings.token ; end
  def protected! ; halt [ 401, '<h4>Not Authorized. <a href="/login"> Login </a> with proper credentials.</h4>' ] unless admin? ; end
end

#### CSS
# css as sass
get '/sass' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end

#get yaml
get "/get_yaml" do
  return DATA.to_json
end


#mainpage
get "/" do
  erb :index
end

get "/test" do
  puts request
  if !request.websocket?
    erb :test
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send("Hello World!")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        puts "this is the msg: #{msg}"
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
      ws.onclose do
        warn("wetbsocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

# main data entry
get "/setup" do
  protected!
  erb :setup
end

# enter main data in database
post "/setup" do
  puts params
  t=Today.new
  return (t.set_setup params).to_json
end

# populate main data entry
get ("/get_setup") {t=Today.new; @setup=t.get_setup.to_json}

#login page
get ("/login") {erb :login}

get ("/entry") do
  protected!
  erb :entry
end

post "/entry" do
  puts params
  on_array=[]; t=Today.new; path_name=params['path_name']
  params.keys.each do |key|
    value=params[key]
    puts value.class
    #regular activities
    t.set_regular(path_name,key,value) if (key!="path_name" and value!="" and (DATA["regular_activities"].has_key? key))
    #checkbox cardinal activity
    if value=="on" then on_array<<key;puts "You have checkboxed #{key} and added it to #{on_array}"; end
    puts "are all conditions met? for #{key} #{(key!="path_name" and value!="" and (DATA["regular_activities"].has_key? key))}"
  end
  #cardinals
  t.set_cardinal path_name, on_array
  EM.next_tick { settings.sockets.each{|s| s.send("Hello things changed for #{path_name}") } }
  return {:ok=>true}.to_json
end

get "/get_entry" do
  Today.new.get_entry.to_json
end

get "/get_tomorrow" do
  Today.new(1).get_entry.to_json
end

get ("/tomorrow") do
  protected!
  erb :tomorrow
end

get "/live" do
  erb :live
end

get "/get_live" do
  Today.new.get_live.to_json
end




post "/tomorrow" do
  puts "***************Tomorrow baby***********"
  puts params
  on_array=[]; t=Today.new 1; path_name=params['path_name']
  params.keys.each do |key|
    value=params[key]
    puts value.class
    #regular activities
    t.set_regular(path_name,key,value) if (key!="path_name" and value!="" and (DATA["regular_activities"].has_key? key))
    #checkbox cardinal activity
    if value=="on" then on_array<<key;puts "You have checkboxed #{key} and added it to #{on_array}"; end
    puts "are all conditions met? for #{key} #{(key!="path_name" and value!="" and (DATA["regular_activities"].has_key? key))}"
  end
  #cardinals
  t.set_cardinal path_name, on_array
  EM.next_tick { settings.sockets.each{|s| s.send("Hello things changed for #{path_name}") } }
  return {:ok=>true}.to_json
end

# updates view for selected pathologist
get "/path/activities/points" do
  t=Today.new
  {path: t.get_path_activities_points}.to_json
end

get "/path/activities/points/tomorrow" do
  t=Today.new 1
  {path: t.get_path_activities_points}.to_json
end



get "/working?" do
  (Today.new).get_path_working.map{ |x| x.ini}.to_json
end

get "/points_total/:initials" do |ini|
end

get "/points_activity/*" do
end

get "/activities_cardinal" do
  {cardinal: DATA["cardinal_activities"].keys.sort}.to_json
end

get "/activities_regular" do
   {regular: DATA["regular_activities"].keys.sort}.to_json
end

get "/path/working" do
   Pathologist.get_path_working.map {|x| x.ini}.sort.to_json
end

get '/today' do
  erb :today
end

#login post
post '/login' do
  #check if tehy match settings
  if params['username']==settings.username&&params['password']==settings.password
      #set a username-token cookie
      response.set_cookie(settings.username,settings.token)
      return true.to_json
    else
      # return false
      response.set_cookie(settings.username, false)
      return false.to_json
    end
end

get('/logout'){ response.set_cookie(settings.username, false) ; redirect '/' }

get '/long_term' do
  '<h3>Work in Progress. <a href="/"> Back to the base. </a> </h3>'
end

get '/report_activity_points/:name' do |name|
  (report_activity_points name).to_json
end

get '/report_activity_points/:name/:subspecialty' do |name, subspecialty|
  (report_activity_points_for_subspecialty name, subspecialty).to_json
end

get "/delta_day/:n" do |n|
  p=PlotterDeltaDay.new

  "<h1>#{get_business_utc(n.to_i).to_date.to_s }</h1> <br> #{p.get p.plot n.to_i} <BR>"
end

get "/delta_summary" do
  p=PlotterDeltaSummary.new
   "<h1>#{get_business_utc(0).to_date.to_s }</h1> <br> #{p.get p.plot} <BR>"

end




get '/websocket' do
  if !request.websocket?
    puts "#{request} #{request.params()} #{!request.websocket?}"
    erb :websocket
  else
    request.websocket do |ws|
      ws.onopen do
        ws.send("Hello World!")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
      ws.onclose do
        warn("wetbsocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

__END__
@@ websocket
<html>
  <body>
     <h1>Simple Echo & Chat Server</h1>
     <form id="form">
       <input type="text" id="input" value="send a message"></input>
     </form>
     <div id="msgs"></div>
  </body>

  <script type="text/javascript">
    window.onload = function(){
      (function(){
        var show = function(el){
          return function(msg){ el.innerHTML = msg + '<br />' + el.innerHTML; }
        }(document.getElementById('msgs'));

        var ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
        ws.onopen    = function()  { show('websocket opened'); };
        ws.onclose   = function()  { show('websocket closed'); }
        ws.onmessage = function(m) { show('websocket message: ' +  m.data); };

        var sender = function(f){
          var input     = document.getElementById('input');
          input.onclick = function(){ input.value = "" };
          f.onsubmit    = function(){
            ws.send(input.value);
            input.value = "send a message";
            return false;
          }
        }(document.getElementById('form'));
      })();
    }
  </script>
</html>



