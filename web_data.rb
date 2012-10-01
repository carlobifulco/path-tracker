my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


require "mongo_mapper"
require "pp"
require "utilities"
require "whenever"
require 'business_time'
require "holidays"
require "statsample"

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

switch_to_testing



####Business day conversion
#
# n is the number of days ahead of today to be converted
#
# Returns a date/time in UTC format of the nth day after today
def get_business_utc n=0
  # if n==0 
  #   if Date.today.sunday? then n=1 end
  #   if Date.today.saturday? then n=2 end
  # end
  business_days=(((1*n).business_day.after Date.today).to_date - Date.today).to_int
  (Date.today+business_days).to_time.utc
end

####Total Daily Cases container
# This is the container of the Pathologist of the day.
# They then have activities...
# The status of this is nt actoamtilly updated in regards of teh many it has (Pathologist and Activities)
# To get the freshest state of the system I do have to pull out again the same Tdc via the today function
# Days are stored as time.utc
# Only TDCs for business days are generated.
class Tdc
  include MongoMapper::Document
  safe
  key :pathologists, Array
  many :pathologist, :in => :pathologists #objects are in pathologist; ids in pathologists
  key :blocks_west, Integer, :default=>0
  key :blocks_east, Integer, :default=>0
  key :tot_points, Integer, :default=>0
  key :blocks_hr, Integer, :default=>0
  key :extra_points_tot, Integer, :default=>0
  key :tot_points_pathologist, Integer, :default=>0
  #Date.today.to_time.utc
  #Tdc.where(:date=>Date.today.to_time.utc).to_a
  key :date, Time

  def show_date
    puts self.date
  end


  ######Returns only one Tdc and always the same for a certain disease
  #
  #n is the number of days from today
  #
  #Returns an instance of Tdc
  def self.today n=0
    business_utc=get_business_utc(n)
    d=where(:date=>business_utc)
    if d.to_a.count>0
      t=d.to_a[0]
      t.date=get_business_utc(n)
      if t.pathologists.count==0 
        t.populate 
        t.save
      end
      return t
    else
      t=Tdc.new
      t.date=business_utc
      if t.pathologists.count==0 then t.populate; t.save  end
      #t.show_date
      return t
    end
  end

  #######Gives the day it's Pathologist
  def populate
    puts "populating???"
    DATA["initials"].each do |ini|
      if not Pathologist.where({:ini=>ini,:date=>self.date}).any?
        p=Pathologist.new({:ini=>ini,:date=>self.date})
        puts "#{p} #{p.ini} #{p.date}"
        if p.save
           puts "saved #{p.ini}" 
        else
          puts "Error(s): ", p.errors.map {|k,v| "#{k}: #{v}"}
        end
        self.pathologist<<p
        puts "#{ini} created with date #{self.date}"
      else
        puts "#{ini} already existing with date #{self.date}"
      end
    end
  self.save
  end

  #only todays match
  def get_path ini
    self.pathologist.select {|x| x.ini==ini}
  end

  def get_working
    self.pathologist.select {|x| x.working==true}
  end

  #Shows who is doing what
  #
  #for debugging purposes
  def get_activities
    self.get_working.each do |p|
      puts "#{p.ini}: specialty-only=#{p.specialty_only}"
      p.activities.each do |a|
        puts "\t#{a.name}: #{a.tot_points}; "
      end
    end
    return nil
  end
end

#index Tdc
Tdc.ensure_index(:date)



#:Numebr of days is here absolute and not business days (n)
class Pathologist
  include MongoMapper::Document
  safe
  belongs_to :tdc
  #initials
  key :ini, String, :required =>true
  key :site, String
  key :date, Time
  key :working, Boolean, :default=>true
  key :specialty_only, Boolean, :default=>false
  many :activities
  key :location, String
  before_save :update_site, :update_specialty_status
  # important  --remove activity if path is at home...
  after_update :delete_activities_if_not_working

  def update_site
    if  DATA["b_psv"].include? self.ini
     self.location="b_psv"
    elsif DATA["c_ppmc"].include? self.ini
      self.location="c_ppmc"
    elsif DATA["d_core"].include? self.ini
      self.location="d_core"
    elsif DATA["a_hr"].include? self.ini
      self.location="a_hr"
    end
    #these before save methods need to return true if all goes well
    return true
  end

  def delete_activities_if_not_working
    #puts "#{self} getting called"
    if not self.working
      #puts "deleting"
      (Activity.find_all_by_pathologist_id  self._id).each do |a|
       # puts "deleting #{a}"
        a.delete
      end
    end
  end

  def update_specialty_status
    #puts "updating specialty status"
    self.activities.each do |a|
      if DATA["distribution-specialty"].include? a.name
        #puts "changing status of #{self.ini} to specialty only true"
        self.specialty_only=true
        return
      end
    end
    self.specialty_only=false
    #these before save methods need to return true if all goes well
    return true
  end

  def self.get_all_path n=0
    d=where(:date=>(Date.today+n).to_time.utc)
    d.to_a if d
  end

  def self.get_path_working n=0
    d=where(:working=>true, :date=>(Date.today+n).to_time.utc)
    d.to_a if d
  end

  def self.get_number_generalist n=0
    self.get_generalist.count
  end

  def self.get_generalist n=0
    self.get_path_working(n).select{|i| i.specialty_only==false}
  end

  def self.get_specialist n=0
    self.get_path_working(n).select{|i| i.specialty_only==true}
  end


  def self.path_all_points n=0
    #n=working_n n
    points_per_path=Today.new(n).points_per_path
    path_all_points=[]
    self.get_path_working(n).each do |x|
      path_all_points<<{ini: x.ini, tot: x.total_points, range: points_per_path, location: x.location}
    end
    path_all_points.sort_by do |a|
      [a[:location],a[:ini]]
    end
  end

  def self.all_paths
    DATA["initials"]
  end

  def self.all_activities_points n=0
    r={}
    self.get_path_working(n).each {|x| r[x.ini]=x.activities_points}
    return r
  end

  def activities_points
    activities_points={}
    self.activities.each {|x| activities_points[x['name']]={tot_points: x['tot_points'],
                                                            n: x[:n]}}
    activities_points
  end
  # checks all activities and sums their points

  def total_points
    self.activities.map{|x| x.tot_points}.reduce(:+) or 0
  end

end

#index Pathologist
Pathologist.ensure_index([[:date, -1], [:working,-1]])

class Activity
  include MongoMapper::Document
  safe
  key :name, String
  key :n,Integer, :default=>0
  key :points, Integer, :default=>0
  key :date, Time, :default=>Date.today.to_time.utc
  key :tot_points, Integer
  #pathologist initials
  key :ini, String
  belongs_to :pathologist
  before_save :update_tot_points
  before_update :update_tot_points

  def self.today n=0
    d=where(:date=>get_business_utc(n))
    d.to_a if d
  end

  def self.get_ini_name n=0, path_ini,activity_name
    path_id=Today.new(n).get_path_by_ini(path_ini)._id
    #puts "PATH-ID=#{path_id}"
    d=where(:date=>get_business_utc(n), :pathologist_id=>path_id, :name=>activity_name)
    d=d.to_a if d
    if d.count >0 then return  d[0] else return false end
  end

  def self.all_activities
    DATA["regular_activities"].merge DATA["cardinal_activities"]
  end


  #all activities points unless slide related
  def self.get_activity_points n=0
    slide_activities=DATA["slide_activities"]; x=0
    self.today(n).each do |a|
       x+=a.tot_points unless slide_activities.member? a.name
    end
    x
  end

  #XXX
  #map to YAML data file
  #eliminate no points activities (i.e Dermath and GI from distribution)
  def self.get_general_slides_distributed n=0
    #n time
    date=get_business_utc n
    #find pathologists ids on derm and GI
    p=where(:date=>date, :name=> DATA["no-points"].keys).all().map {|x| x.ini}
    #find all cases with slides
    m=where(:date=>date, :name=> ["Slides-large-cases", "Slides-small-cases"],  :ini=> {:$nin=>p}).all

    return m.map {|x| x.n}.reduce(:+)
    #.map{|x| x.n}.reduce(:+)

  end

  def update_tot_points
      self.tot_points=self.points*self.n
  end
end


#index activities
Activity.ensure_index([[:date, -1], [:pathologist_id, 1], [:name,1]])




# Main interface to the web application
# Setter methods
module TodaySet
  def set_path_off ini
    p=self.get_path_by_ini ini
    p.working=false
    p.save
  end

  def set_blocks_west n
    t=Tdc.today @n
    t.blocks_west=n
    t.save
    puts "blocks west #{t.blocks_west}"
  end

  def set_blocks_east n
    t=Tdc.today @n
    t.blocks_east=n
    t.save
    puts "blocks eats #{t.blocks_east}"
  end

  def set_blocks_hr n
    t=Tdc.today @n
    t.blocks_hr=n
    t.save
  end

  def set_path_on ini
    p=get_path_by_ini ini
    p.working=true
    p.save
  end

  def set_present ini_array
    ini_array.each {|ini| set_path_on ini}
  end

  def set_absent ini_array
    ini_array.each {|ini|  set_path_off ini}
  end

end

# Main interface to the web application
# Getter methods
module TodayGet
  def get_path_all
    t=Tdc.today @n
    t.pathologist
  end
   #magic souce formula....
  def get_points_slide_tot
     t=Tdc.today @n
     #conversion blocks slides
     total_slide_points= SLIDES_CONVERSION_FACTOR * (t.blocks_west+t.blocks_east+t.blocks_hr)
     total_slide_points.to_int
  end
  #these are theroetical based on the number of blocks/slides to be distributed
  def get_points_tot
    t=Tdc.today @n
    #puts "Slides:#{self.get_points_slide_tot()};Activity: #{Activity.get_activity_points(@n)} "
    t.tot_points=(self.get_points_slide_tot() + Activity.get_activity_points(@n))
    #puts t.tot_points
    t.save
    return t.tot_points
  end

  #this includes pnly actual slides distributed
  def get_real_points_distributed
    self.get_general_slides_distributed+Activity.get_activity_points(@n)
  end

  def get_path_working
    t=Tdc.today @n
    t.pathologist.select {|x| x.working==true}
  end

  def get_number_path_working
    self.get_path_working().count
  end

  def get_path_specialty
    t=Tdc.today @n
    # only if working....
    t.pathologist.select {|x| x.specialty_only==true} &  t.pathologist.select {|x| x.working==true}
  end

  def get_path_absent
    t=Tdc.today @n
    t.pathologist.select {|x| x.working==false}.map {|x| x.ini}
  end

  def get_general_slides_distributed
    Activity.get_general_slides_distributed @n
  end

  def get_slides_to_be_distributed
    (get_points_slide_tot/SLIDES_CONVERSION_FACTOR)-get_general_slides_distributed
  end

  def get_path_by_ini ini
    t=Tdc.today @n
    p=t.pathologist.select {|x| x.ini==ini}
    p[0] if p.count>0
  end
end


module TodayReport
  def report_day
    average_generalist_effective_workload=self.get_real_points_distributed/Pathologist.get_number_generalist
    puts "Day #{Date.today+working_n(@n)}"
    puts "**************"
    puts "\t- Total non-slide points assigned: #{Activity.get_activity_points n}"
    puts "\t- Predicted slides to be distributed: #{self.get_points_slide_tot}"
    puts "\t- Total slides distributed: #{Activity.get_general_slides_distributed n}"
    puts "\t- Diff slides predicted vs distributed: #{self.get_points_slide_tot - (Activity.get_general_slides_distributed n)}"
    puts "\t- Average (mean) theoretical workload per generalist Pathologist: #{self.get_points_tot/Pathologist.get_number_generalist}"
    puts "\t- Average (mean) effective workload per generalist Pathologist: #{average_generalist_effective_workload}"

    puts "*************"
    puts "-Generalist Distribution:"
    Pathologist.get_generalist.each do |p|
      puts "\tDeviation from mean for #{p.ini}: #{-(average_generalist_effective_workload-p.total_points)}"
    end
  end
end

#### Main interface to sinatra calls
class Today
  include TodaySet
  include TodayGet
  include TodayReport

  attr_accessor :tdc, :n, :all_activities_points, :time, :date

  def initialize n=0
    @all_activities_points= DATA["regular_activities"].merge DATA["cardinal_activities"]
    # @ n is the number of days after today; needs to tak into accound weekends/holidays
    @n=n
    @time=get_business_utc n
    @date=@time.to_date
    #actuallu used only for debugging
    @tdc=Tdc.today n
  end


  # all paths for the day
  def get_setup
    #Tdcs need to be genrated fresh for each call
    t=Tdc.today @n
    tot_points=self.get_points_tot()
    blocks_tot=t.blocks_west+t.blocks_east+t.blocks_hr; slide_points=(blocks_tot*SLIDES_CONVERSION_FACTOR).to_i
    slides_distributed=Activity.get_general_slides_distributed(@n); ; activity_points=tot_points-slide_points
    if slides_distributed then slides_remaining=slide_points - slides_distributed else slides_remaining=slide_points/SLIDES_CONVERSION_FACTOR end
    pathologist_working=self.get_path_working.map { |x| x.ini }
    path_count= self.get_path_working.count
    setup={blocks_west: t.blocks_west,
          blocks_east: t.blocks_east,
          blocks_hr: t.blocks_hr,
          blocks_tot: blocks_tot,
          tot_points: tot_points,
          slide_points: slide_points,
          activity_points: activity_points,
          pathologist_all: self.get_path_all.map { |x| x.ini  },
          pathologist_working: (pathologist_working).sort,
          pathologist_absent: (self.get_path_absent).sort,
          path_count: path_count,
          date: @date.to_s,
          slides_distributed: slides_distributed,
          slides_remaining: slides_remaining,
          generalist_count:Pathologist.get_number_generalist
          }
    setup[:points_per_pathologist]=  self.points_per_path
    return setup
  end

  # equation for asserting total points per head
  def points_per_path
    tot_points=self.get_points_tot
    path_count= self.get_path_working.count-self.get_path_specialty.count
    if path_count !=0
      tot_points/path_count
    else
      return 1
    end
  end


  def set_setup params
    t=Tdc.today @n
    #puts params
    #puts " params is #{params}; and has key #{params.has_key? 'blocks_east'}"
    self.set_blocks_east params['blocks_east'] #unless (not (params.has_key? 'blocks_east'))
    self.set_blocks_west params['blocks_west'] #unless (not (params.has_key? 'blocks_west'))
    self.set_blocks_hr params['blocks_hr']
    #puts "where are you #{params['blocks_hr']}"
    self.set_present(params['path_present']) unless (not (params.has_key? 'path_present'))
    self.set_absent(params['path_absent']) unless (not (params.has_key? 'path_absent'))
    return true
  end

  def get_entry
    t=Tdc.today @n
    entry={pathologist_working: Pathologist.get_path_working(@n).map{ |x| x.ini}.sort(),
      paths_acts_points: Pathologist.all_activities_points(@n),
      paths_tot_points: Pathologist.path_all_points(@n)
     }
  end

  def get_path_activities_points
    return Pathologist.all_activities_points @n
  end

  #activities entry point for regular
  def set_regular path_ini, activity_name, n
    p=self.get_path_by_ini path_ini
    a=self.get_activity path_ini, activity_name
    a.n=n
    p.activities<<a
    a.save
    p.save
    pp "just updated for you #{path_ini}'s #{a.name} to a number of #{a.n} and tot_points of #{a.tot_points} "
  end

  #activities entry point for cardinal
  def set_cardinal path_ini, on_array
    no_work_activities=DATA["no-points"].keys
    p=self.get_path_by_ini path_ini
    off_array=DATA["cardinal_activities"].keys.select{|x| not (on_array.member? x)}
    #puts "on: #{on_array}; not on #{off_array}"
    on_array.each do |activity_name|
      a=self.get_activity path_ini, activity_name
      a.n=1
      p.activities<<a
      a.save
      # if activity is one of the no-work-acts them set pathologist as specialty only
      #puts "Specialty? :#{DATA["no-points"].keys.include? activity_name}"
      if DATA["no-points"].keys.include? activity_name
        p.specialty_only=true
      end
    end
    off_array.each do |activity_name|
      a=Activity.get_ini_name(@n,path_ini,activity_name)
      a.delete if a
    end
    p.save
  end

  def get_activity path_ini, activity_name
    r=Activity.where(:ini=>path_ini,:date=>@time,:name=>activity_name)
    if r.count==1
      puts "existing activity"
      return r.all[0]
    # p=self.get_path_by_ini path_ini
    # path_existing_activities=p.activities.map{|x| x.name}
    # if path_existing_activities.member? activity_name
    #    a=Activity.get_ini_name(@n, path_ini,activity_name)
    else
      puts "new activity"
      a=Activity.new
      a.date=@time
      a.name=activity_name
      a.ini=path_ini
      if @all_activities_points.has_key? activity_name then a.points=@all_activities_points[activity_name] else return false end
    end
    return a
  end

  def save_activity path_ini, activity_name, n=false
  end
end



