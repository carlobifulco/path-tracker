require "colored"
require "uri"

### if running on docker
if ENV.has_key? "DB_PORT"
  x=URI.parse ENV["DB_PORT"]
  uri="mongodb://"+x.host+":"+x.port.to_s
  ENV['MONGODB_URI']=uri
  MONGO_HOST=x.host
  MONGO_PORT=x.port
  puts "connecting to mongo at: #{uri.green}"
else
  uri="mongodb://"+"localhost"+":"+"27017"
  ENV['MONGODB_URI']=uri
  MONGO_HOST="localhost"
  MONGO_PORT="27017"
  puts "Local Mongod".green
end
