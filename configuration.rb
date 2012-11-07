####TO install Rserve
# R CMD INSTALL  Rserve_1.7-0.tar.gz
# R CMD Rserve
$my_directory=File.dirname(File.expand_path(__FILE__))


require "whenever"
require 'business_time'
require "holidays"
require "mongo_mapper"
require "redis"
require "redis-namespace"





#####Configuration
#-------------

#####MongoDumping
DUMP_DIRECTORY= "/Users/carlobifulco/mongodump"
Dir.mkdir DUMP_DIRECTORY unless Dir.exists? DUMP_DIRECTORY


#####Redis configutation
# :password=>"redisreallysucks",
$redis=Redis.new(:thread_safe=>true,:port=>6379,:host=>$HOST)
# Redis table
UseDb=1
ConfigurationDb=2
$redis.select UseDb




#####Dump of database
#-----------------

system "whenever  --load-file #{File.join $my_directory,'config/schedule.rb'} --update-crontab "


####Holidays observed at work
#----------------------------
OBSERVED=["Memorial Day","Independence Day", "Labor Day", "Thanksgiving", "Christmas Day","New Year's Day"]
all_observed=Holidays.between(Date.today, 2.years.from_now, :us).select{|x| OBSERVED.include? x[:name]}
####Config business day to include those holidays
all_observed.map{|holiday| BusinessTime::Config.holidays << holiday[:date]}





def switch_to_testing
  $data_basename='test'
  $data_file=File.join($my_directory,"./base_line_data.yml")
  $redis_testing=true
  set :port, 5000
  puts "SWITTCHED TO TEST DATABASE"

  puts "********************************************************"
  puts "Using database #{$data_basename} and setting #{$data_file}"
  puts "********************************************************"
  MongoMapper.database = $data_basename

end

def switch_to_production
  $data_basename='path-tracker'
  $data_file=File.join($my_directory,"./base_line_data.yml")
  $redis_testing=false
  puts "SWITTCHED TO PRODUCTION DATABASE!!!"

  puts "********************************************************"
  puts "Using database #{$data_basename} and setting #{$data_file}"
  puts "*******"
  MongoMapper.database = $data_basename
end

#### Remote login into mongohq  --too slow in real life
#mongoHQ command line mongo alex.mongohq.com:10029/path-tracker -u carlobifulco  -p bifulcocarlo
#MongoMapper.connection = Mongo::Connection.new('alex.mongohq.com',10029)
#MongoMapper.database.authenticate('carlobifulco', 'bifulcocarlo')



#####Slide conversion factor
#------------------------
SLIDES_CONVERSION_FACTOR=0.8



