my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << my_directory; $LOAD_PATH << File.join(my_directory,'/lib')


require 'rufus/scheduler'
require 'report_new'


#####MongoDumping
DUMP_DIRECTORY= "/Users/carlobifulco/Dropbox/mongo_path_tracker"
Dir.mkdir DUMP_DIRECTORY unless Dir.exists? DUMP_DIRECTORY
Dir.mkdir (DUMP_DIRECTORY+"/dump") unless Dir.exists? (DUMP_DIRECTORY+"/dump") 


#Scheduling
#-----------

$scheduler = Rufus::Scheduler.start_new


# at 23 hours on all days 
$scheduler.cron '0 23 * * 1-7' do
  # every day of the week at 11pm
  puts 'activate reportimg system'
  report_build
  puts "report completed"
end

def mongodump
  command= "mongodump -d path-tracker -o /Users/carlobifulco/Dropbox/mongo_path_tracker/dump"
  puts command
  system command
end

def mongoexport
  command="mongoexport --collection activities --out /Users/carlobifulco/Dropbox/mongo_path_tracker/activities.json"
  puts command
  system command
end

# every day of the week at 10pm
$scheduler.cron '0 22 * * 1-7' do
  puts "mongo-dumping"
  mongodump
end

# every day of the week at 10pm and 5 minutes
$scheduler.cron '5 22 * * 1-7' do
  puts "mongo-exporting"
  mongoexport
end

# #checkning that sceduler is alive
# $scheduler.every '60m' do
#    puts "Hola; 60 minutes passed #{Time.now}"
#  end


#If not in event machine enviroment
#$scheduler.join
puts "\n---------------------------------------"
puts "**************#{$scheduler.all_jobs.keys}**************"
puts "\n----------------------------------------"
