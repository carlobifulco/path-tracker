#libs for the generation of the DOT Files
#add the current dir  and lib to the load path
my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


require "sinatra"
require "haml"
require 'sinatra/mustache'

# in 
require "web_data"


#SINATRA SETUPS
#----------------
set :root, File.dirname(__FILE__)
set :haml, {:format => :html5 }
# Keeping coffee, compiled JS and haml files in the same directory
set :views, Proc.new { File.join(root, "public/views") }
enable :sessions

# CSS
#-----
# css as sass
get '/sass' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end


#mainpage redirection for cache reasons
get "/" do
  "Hello suckers"
  @name="CAT"
  mustache :index
end


# test
get "/test" do
  "Hello suckers 8"
end

  
get "/setup" do
  t=Today.new
end