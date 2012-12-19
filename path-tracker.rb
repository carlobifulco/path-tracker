#libs for the generation of the DOT Files
#add the current dir  and lib to the load path
my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory

require "bundler/setup"
require "sinatra"
require "configuration"
require "mongo_mapper"




require "web_data"
#require "bundler/setup"
require 'coffee-script'

require 'sinatra-websocket'
#require "report_svg"
#require "report_new"





set :server, 'thin'
set :sockets, []


set :username,'total'
set :token,'shakenN0tstirr3d'
set :password,'recall'



####SINATRA SETUPS
set :root, File.dirname(__FILE__)





# Keeping coffee, compiled JS and html5 in the same directory
set :views, Proc.new { File.join(root, "public/views") }
enable :sessions


####helpers
#These have access to the params in  sinatra get/post funtions
helpers do
  def admin? ; request.cookies[settings.username] == settings.token ; end
  def protected! ; halt [ 401, '<h4>Not Authorized. <a href="/login"> Login </a> with proper credentials.</h4>' ] unless admin? ; end
  def log_event n
    log=Log.new
    log.request=params.to_json
    log.time=Time.now.utc
    log.path_ini=request["path_name"]
    log.date=get_business_utc n
    log.ip=request.ip
    puts "Created new log with a date of : #{log.date}"
    log.save
  end
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

get "/get_setup/:n" do |n|
  t=Today.new n.to_i
  @setup=t.get_setup.to_json
end

# Used by tomorrow
post "/setup/:n" do |n|
  puts params
  t=Today.new n.to_i
  return (t.set_path_tomorrow params).to_json
end

#login page
get ("/login") {erb :login}

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

# main interface
get ("/entry") do
  protected!
  erb :entry
end

#main data entry for days slides/activities
post "/entry" do
  #puts "the request is coming from #{request.ip} at #{Time.now}"
  log_event 0
  puts params
  on_array=[]; t=Today.new; path_name=params['path_name']
  params.keys.each do |key|
    value=params[key]
    #puts value.class
    #regular activities
    t.set_regular(path_name,key,value) if (key!="path_name" and value!="" and (DATA["regular_activities"].has_key? key))
    #checkbox cardinal activity
    if value=="on" then on_array<<key;end
    #puts "are all conditions met? for #{key} #{(key!="path_name" and value!="" and (DATA["regular_activities"].has_key? key))}"
  end
  #cardinals
  t.set_cardinal path_name, on_array
  #EM.next_tick { settings.sockets.each{|s| s.send("Hello things changed for #{path_name}") } }
  return {:ok=>true}.to_json
end

# populates data entry for days slides/activities
get "/get_entry" do
  Today.new.get_entry.to_json
end

#populates the tomorrow window
get "/get_tomorrow" do
  Today.new(1).get_entry.to_json
end


get ("/tomorrow") do
  protected!
  erb :tomorrow
end

get ("/tomorrow_path") do
  protected!
  erb :tomorrow_path
end

get "/live" do
  erb :live
end

get "/get_live" do
  Today.new.get_live.to_json
end

get "/get_dashboard" do
  r=report_json
  r.to_json
end

get "/dashboard" do
  erb :dashboard
end



post "/tomorrow" do
  puts "***************Tomorrow baby***********"
  puts params
  log_event 1
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
  #EM.next_tick { settings.sockets.each{|s| s.send("Hello things changed for #{path_name}") } }
  return {:ok=>true}.to_json
end

##### updates view for selected pathologist
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



get('/logout'){ response.set_cookie(settings.username, false) ; redirect '/' }

get '/long_term' do
  '<h3>Work in Progress. <a href="/"> Back to the base. </a> </h3>'
end

#### reporting activities
#--------------------------

get '/report_activity_points/:name' do |name|
  (ReportActivity.report_activity_points name).to_json
end

get '/report_activity_points/:name/:subspecialty' do |name, subspecialty|
  (ReportActivity.report_activity_points_for_subspecialty name, subspecialty).to_json
end


####APIs
#-------
#xxx
get "/delta_day/:n" do |n|
  if n.to_i>=0 then return "<h1> Cannot do this in the future and the day is not yet over </h1>" end
  p=PlotterDeltaDay.new
  "<h1>#{get_business_utc(n.to_i).to_date.to_s }</h1> <br> #{p.get p.plot n.to_i} <BR>"
end

#xxx
get "/delta_summary" do
  p=PlotterDeltaSummary.new
   "<h1>#{get_business_utc(0).to_date.to_s }</h1> <br> #{p.get p.plot} <BR>"
end


get "/past_ini_date/:ini/:n" do |ini,n|
  results="<h1>#{ini}: Summary for #{get_business_utc(n.to_i)}</h1>"
  puts ini, n
  if n.to_i>=0 then return "<h1> Cannot do this in the future and the day is not yet over </h1>" end
  puts  (Activity.where :date=>get_business_utc(n.to_i), :ini=>ini).all
  (Activity.where :date=>get_business_utc(n.to_i), :ini=>ini).all.each {|x| results += "<h3>#{x.name}: #{x.tot_points}</h3>"}
  results
end

# logging info for pathologist; day n=0
get "/log/:ini" do |ini|
  Log.get_ini ini
end

get "/log/:ini/:n" do |ini,n|
   Log.get_ini n.to_i,ini
end


### API's summary
get "/api" do
  protected!
  erb :api
end

get "/log_of_day_events" do
  protected!
  erb :log_of_day_events
end


#### Experiments
#------------------

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



#scockets games

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



