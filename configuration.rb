####TO install Rserve
# R CMD INSTALL  Rserve_1.7-0.tar.gz
# R CMD Rserve


#testing argv data here ["-p", "4000", "test"] --first 2 args are ports
puts "argv data here #{ARGV}"
puts "enter testing argv data here [-p, 4000, test] --first 2 args are ports"
if ARGV[2] =="test" then TESTING=true else TESTING=false end
puts "testig is #{TESTING}"


#####Configuration
#-------------
if not TESTING
  DATA_BASENAME='path-tracker'
  DATA_FILE="./base_line_data.yml"
else
  DATA_BASENAME='test'
  DATA_FILE="./base_line_data_test.yml"
end

#####Slide conversion factor
#------------------------
SLIDES_CONVERSION_FACTOR=1.2

puts "********************************************************"
puts "Using database #{DATA_BASENAME} and setting #{DATA_FILE}"
puts "********************************************************"

#####Dump of database
#-----------------

system "whenever --update-crontab path-tracker"


####Holidays observed at work
OBSERVED=["Memorial Day","Independence Day", "Labor Day", "Thanksgiving", "Christmas Day","New Year's Day"]
all_observed=Holidays.between(Date.today, 2.years.from_now, :us).select{|x| OBSERVED.include? x[:name]}
####Config business day to include those holidays
all_observed.map{|holiday| BusinessTime::Config.holidays << holiday[:date]}


# Remote login into mongohw  --too slow in real life
#mongoHQ command line mongo alex.mongohq.com:10029/path-tracker -u carlobifulco  -p bifulcocarlo
#MongoMapper.connection = Mongo::Connection.new('alex.mongohq.com',10029)
#MongoMapper.database.authenticate('carlobifulco', 'bifulcocarlo')

#### Local login
MongoMapper.database = DATA_BASENAME
DATA=YAML.load(File.read DATA_FILE)

def switch_to_testing
  MongoMapper.database = 'test'
  puts "SWITTCHED TO TEST DATABASE"
end

def switch_to_production
  MongoMapper.database = DATA_BASENAME
  puts "SWITTCHED TO TEST DATABASE"
end

switch_to_testing
