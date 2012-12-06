my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


require "mongo_mapper"

require "whenever"
require 'business_time'
require "holidays"
require "interface"
require "sinatra"
require "configuration"



####decides if testing or production based on working directory
#Testing unless prduction
puts "HELLO FROM YOU FRIENDLY PATH-TRACKER; my #{ARGV}"

unless ARGV[0] =="production"
  case File.basename(my_directory)
    when "path-tracker-deploy"
      puts "I am deploying production"
      switch_to_production
    when "path-tracker"
      puts "I am deployng testing"
      switch_to_testing
  end
end

#overrides entry if needed
if ARGV[0] =="production" then switch_to_production; set :port, 5000 ; end


#### Local logins
MongoMapper.database = $data_basename
DATA=YAML.load(File.read $data_file)

### these need to have an existing database connection
require "utilities"
require "report_svg"
require "report_new"


class Date
  def utc
    self.to_time.utc
  end
end


####Business day conversion
#
# n is the number of days ahead of today to be converted
#
# Returns a date/time in UTC format of the nth day after today
def get_business_utc n=0
  #if future
  if n >= 0
    business_days=(((1*n).business_day.after Date.today).to_date - Date.today).to_int
    return (Date.today+business_days).to_time.utc
  else
  # if past
    business_days=(Date.today - ((- n).business_day.before Date.today).to_date).to_int
    return (Date.today-business_days).to_time.utc
  end
end


def get_n_from_utc utc_time
  - (utc_time.to_date.business_days_until Date.today)
end

####Total Daily Cases container
# This is the days container
# It has Pathologists of the day.
# And they then have activities...
# The status of this is nt actoamtilly updated in regards of teh many it has (Pathologist and Activities)
# To get the freshest state of the system I do have to pull out again the same Tdc via the today function
# Days are stored as time.utc
# Only TDCs for business days are generated.
class Tdc
  include MongoMapper::Document
  safe
  key :pathologists, Array
  many :pathologist, :in => :pathologists #objects are in pathologist; ids in pathologists
  #old entries
  key :blocks_west, Integer, :default=>0
  key :blocks_east, Integer, :default=>0
  key :blocks_hr, Integer, :default=>0
  # new entries
  key :tot_points, Integer, :default=>0
  key :blocks_tot,Integer, :default=>0
  key :total_GI, Integer, :default=>0
  key :total_SO, Integer, :default=>0
  key :total_ESD, Integer, :default=>0
  key :left_over_previous_day_slides, Integer, :default=>0
  key :total_cytology, Integer, :default=>0
  key :expected_generalist_distribution_slides, Integer, :default=>0
  key :tot_points_pathologist, Integer, :default=>0
  # date stores the Tdc instance day in a utc representation of the date
  # this is the dataset used to pull out Tdc instances if they are already existing
  key :date, Time
  #n is the number of **working** days ahead of today
  key :n, Integer


  def show_date
   #
    puts self.date
  end


  ######Returns only one Tdc and always the same for a certain day
  #
  #n is the number of days from today
  #
  #Returns an instance of Tdc
  def self.today n=0
    business_utc=get_business_utc(n)
    d=where(:date=>business_utc)
    # existing instance n working days ahead of today
    if d.to_a.count>0
      t=d.to_a[0]
      # update the t.n (t.n was setup on the day of creation but now it could have to be changed)
      t.n=(Date.today.business_days_until t.date.to_date) if (Date.today <= t.date.to_date)
      t.n= - (t.date.to_date.business_days_until Date.today) if (Date.today > t.date.to_date)
      if t.pathologist.count==0
        t.populate
      end
      t.save
      return t
    # new instance
    else
      t=Tdc.new
      t.n=n
      t.date=business_utc
      if t.pathologist.count==0 then t.populate; t.save  end
      return t
    end
  end

  #######Gives the day it's Pathologist
  def populate
    puts "populating???"
    DATA["initials"].each do |ini|
      #create if not existing
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
      #append if existing and not loaded
      else
        self.pathologist<<Pathologist.where({:ini=>ini,:date=>self.date}).first
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
  # for all dates
  #
  #for debugging purposes
  def debug
    Tdc.all.sort_by{|x| x.date}.each do |t|
      puts "Date: #{t.date}, Working days: #{t.n}"
      t.get_working.each do |p|
        puts "\t#{p.ini}: specialty-only=#{p.specialty_only}"
        p.activities.each do |a|
          puts "\t\t#{a.name}: #{a.tot_points}; "
        end
      end
    end
    return nil
  end

  #magic souce formula....
  # total of all expected slide points
  #blocks enetered are generalist blocks only
  def get_predicted_points_slide_tot
     #conversion blocks slides
     total_slide_points= SLIDES_CONVERSION_FACTOR * (self.blocks_west+self.blocks_east+self.blocks_hr)
     total_slide_points.to_int
  end

  #tot of all expected points
  #again generalist blocks and activities only
  def get_predicted_points_all
    self.tot_points=(self.get_predicted_points_slide_tot + Activity.get_general_non_slide_points(self.n))
  end
end


#index Tdc
Tdc.ensure_index(:date)


def tot_points path_list
  activities=[]
  path_list.each{|p| activities+=p.activities}
  activities.map{|a|a.tot_points}.reduce(:+)
end


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
  #array where instances of Activity get packed and assigned via <<
  many :activities
  key :location, String
  before_save :update_site
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


  #this needed to be done at a pathologist level
  #Otherives had save save atcivity loops...
  # This is called from interface.rb if cardinal activity matches list
  # of psecialty only cases
  def update_specialty_status activity_name
    #puts "updating specialty status"
    self.activities.each do |a|
        a.specialty_only=true
        a.specialty=activity_name
        a.save
    end
  end

  def self.get_all_path n=0
    d=where(:date=>(get_business_utc(n)))
    d.to_a if d
  end

  def self.get_path_working n=0
    d=where(:working=>true, :date=>(get_business_utc(n)))
    d.to_a if d
  end

  def self.get_number_generalist n=0
    self.get_generalist(n).count
  end

  def self.get_generalist n=0
    self.get_path_working(n).select{|i| i.specialty_only==false}
  end

  def self.get_specialist n=0
    self.get_path_working(n).select{|i| i.specialty_only==true}
  end

  # Main data structure for rendering
  #
  # Returns dict with initials, points range, location and pathologist initial
  def self.path_all_points n=0, pathologist=self.get_path_working(n)
    #n=working_n n
    t=Tdc.today(n)
    pc=PointsCalculator.new
    points_per_path=pc.predicted_points_per_non_specialist
    path_all_points=[]
    pathologist.each do |x|
      path_all_points<<{ini: x.ini, tot: x.total_points, slides: x.slide_points, range: points_per_path, location: x.location}
    end
    # Sort by location
    path_all_points.sort_by do |a|
      [a[:location],a[:ini]]
    end
  end

  def self.path_all_points_generalist n=0
    self.path_all_points(n,self.get_generalist(n))
  end

  def self.path_all_points_specialist n=0
    self.path_all_points(n,self.get_specialist(n))
  end

  def self.all_paths
    DATA["initials"]
  end

  #main data source for visualization of bars in entry
  def self.all_activities_points n=0
    r={}
    self.get_path_working(n).each {|x| r[x.ini]=x.activities_points}
    return r
  end

  def self.all_activities_points_generalist n=0
    r={}
    self.get_generalist(n).each {|x| r[x.ini]=x.activities_points}
    return r
  end
  #main data source for visualization of bars in live
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

  #selected slide related activity and return the sum of their points
  def slide_points
    self.activities.select{|a| DATA["slide_activities"].include? a.name}.map{|x| x.tot_points}.reduce(:+) or 0
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
  key :specialty_only, Boolean, :default=>false
  key :specialty, String, default=""
  belongs_to :pathologist
  before_save :update_tot_points, :update_time
  before_update :update_tot_points
  key :updated_at, Array
  before_destroy :uncheck_subspecialty


  # callback.  Time stamp array.  Only if N is modified or new
  def update_time
    if self.updated_at == []
       self.updated_at << [self.n,Time.now()]
    else
       self.updated_at  << [self.n,Time.now()] if (self.updated_at[-1][0] != self.n)
    end
  end


  #callback ; called upon destruction
  #resets specialty staus of other activities owner by the pathologist
  def uncheck_subspecialty
      if DATA["distribution-specialty"].keys.include? self.name
        (Activity.where :pathologist_id => self.pathologist_id).all.each do |a|
          a.specialty_only=false
          a.specialty=""
          a.save
        end
      end
  end

  def self.today n=0
    d=where(:date=>get_business_utc(n))
    d.to_a if d
  end

  def self.get_ini_name n=0, path_ini,activity_name
    d=where(:date=>get_business_utc(n), :ini=>path_ini, :name=>activity_name)
    d=d.to_a if d
    if d.count >0 then return  d[0] else return false end
  end

  def self.all_activities
    DATA["regular_activities"].merge DATA["cardinal_activities"]
  end


  #all activities points unless slide related
  def self.get_non_slide_points n=0
    slide_activities=DATA["slide_activities"]; x=0
    self.today(n).each do |a|
       x+=a.tot_points unless slide_activities.member? a.name
    end
    x
  end

  def self.get_specialist_slides_distributed n=0
    date=get_business_utc n
    #find pathologists ids on derm and GI
    p_inis=where(:date=>date, :name=> DATA["no-points"].keys).all().map {|x| x.ini}
    #find slide activities with non specialist
    m=where(:date=>date, :name=> DATA["slide_activities"], :ini=>p_inis).all
    return ((m.map{|x| x.tot_points}.reduce(:+)) or 0)
  end

  def self.get_specialist_non_slide_points n=0
    date=get_business_utc n
    #find pathologists ids on derm and GI for the day
    p_inis=where(:date=>date, :name=> DATA["no-points"].keys).all().map {|x| x.ini}
    #find slide activities with non specialist
    m=where(:date=>date, :name=> {:$nin=>DATA["slide_activities"]}, :ini=>p_inis).all
    return ((m.map{|x| x.tot_points}.reduce(:+)) or 0)
  end

  #searches subspecialists for the activity date
  # and the checks is the
  def has_path_subspecialty? subspecialty_name
    self.pathologist.activities.map{|x| x.name}.include? subspecialty_name
  end

 #all activities points only for generalists unless slide related
  def self.get_general_non_slide_points n=0
    date=get_business_utc n
    #find pathologists ids on derm and GI
    p_inis=where(:date=>date, :name=> DATA["no-points"].keys).all().map {|x| x.ini}
    #m=where(:date=>date, :name=> {:$nin=>DATA["slide_activities"]},  :ini=> {:$nin=>p}).all
    m=where(:date=>date, :name=> {:$nin=>DATA["slide_activities"]}, :ini=> {:$nin=>p_inis}).all
    return ((m.map{|x| x.tot_points}.reduce(:+)) or 0)
  end


  #XXX
  #map to YAML data file
  #eliminate no points entries (i.e Dermath and GI  and hemepath only from distribution)
  #since points per slides ==1 this gives also teh total number of slides points
  def self.get_general_slides_distributed n=0
    #n time
    date=get_business_utc n
    #find pathologists ids on derm and GI
    p=where(:date=>date, :name=> DATA["no-points"].keys).all().map {|x| x.ini}
    #find all cases with slides
    m=where(:date=>date, :name=> DATA["slide_activities"],:specialty_only=> false)

    return ((m.map {|x| x.n}.reduce(:+)) or 0)
    #.map{|x| x.n}.reduce(:+)

  end

  def update_tot_points
      self.tot_points=self.points*self.n
  end
end


#index activities
Activity.ensure_index([[:date, -1], [:pathologist_id, 1], [:name,1]])



class Log
  include MongoMapper::Document
  safe
  key :path_ini, String
  key :request, String
  key :date, Time, :default=>Date.today.to_time.utc
  key :time, Time
  key :ip, String


  def self.get_ini n=0, path_ini
    d=where(:date=>get_business_utc(n), :path_ini=>path_ini)
    d=d.to_a if d
    if d.count >0 
      d.each  do  |log| 
        puts "#{log.ip}: #{log.time.to_time}\n\t #{JSON.parse(log.request)}" 
      end
    else 
      return false
    end
  end
end





