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
require "haml"


set :username,'Bond'
set :token,'shakenN0tstirr3d'
set :password,'007'




####SINATRA SETUPS
set :root, File.dirname(__FILE__)
set :haml, {:format => :html5 }
# Keeping coffee, compiled JS and haml files in the same directory
set :views, Proc.new { File.join(root, "public/views") }
enable :sessions

####helpers
#These have access to the params in  sinatra get/post funtions

helpers do
  def admin? ; request.cookies[settings.username] == settings.token ; end
  def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
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

# test
get ("/test") {"Hello suckers 8888"}

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



