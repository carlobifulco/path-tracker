#libs for the generation of the DOT Files
#add the current dir  and lib to the load path
my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


# in
require "web_data"


#require "bundler/setup"
require 'coffee-script'
require "sinatra"
require "erb"
require 'sinatra/mustache'
require "pp"



set :username,'Bond'
set :token,'shakenN0tstirr3d'
set :password,'007'




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
end

#### CSS
# css as sass
get '/sass' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end

#mainpage
get "/" do
  erb :index
end

get "/test" do
   erb :test
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

get "/get_entry" do
  t=Today.new
  t.get_entry.to_json
end

get "/path/activities/points" do
  {path: Pathologist.all_activities_points}.to_json
end

post "/entry" do
  pp params
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
  return {:ok=>true}.to_json
  
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



