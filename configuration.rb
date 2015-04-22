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
require "yaml"
#require "web_data"





#####Configuration
#-------------




#####Redis configutation
# :password=>"redisreallysucks",
$redis=Redis.new(:thread_safe=>true,:port=>6379,:host=>$HOST)
# Redis table
UseDb=1
ConfigurationDb=2
$redis.select UseDb




#####Dump of database
#-----------------

# system "whenever  --load-file #{File.join $my_directory,'config/schedule.rb'} --update-crontab "


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

####decides if testing or production based on working directory
#Testing unless prduction
puts "HELLO FROM YOU FRIENDLY PATH-TRACKER; my #{ARGV}"

unless ARGV[0] =="production"
  case File.basename($my_directory)
    when "path-tracker-deploy"
      puts "I am deploying production"
      switch_to_production
    when "path-tracker"
      puts "I am deployng testing"
      switch_to_testing
    else
      switch_to_testing
  end
end



#### Remote login into mongohq  --too slow in real life
#mongoHQ command line mongo alex.mongohq.com:10029/path-tracker -u carlobifulco  -p bifulcocarlo
#MongoMapper.connection = Mongo::Connection.new('alex.mongohq.com',10029)
#MongoMapper.database.authenticate('carlobifulco', 'bifulcocarlo')


#### Local logins
MongoMapper.database = $data_basename
DATA=YAML.load(File.read $data_file)

#####Slide conversion factor
#------------------------
SLIDES_CONVERSION_FACTOR=DATA["slides_conversion_factor"]
puts "CONVERSION FACTOR=#{SLIDES_CONVERSION_FACTOR}"
