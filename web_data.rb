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
require "interface"
require "configuration"



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
      if t.pathologist.count==0
        t.populate
        t.save
      end
      return t
    else
      t=Tdc.new
      t.date=business_utc
      if t.pathologist.count==0 then t.populate; t.save  end
      #t.show_date
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
    self.get_generalist(n).count
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
    #find pathologists ids on derm and GI
    p_inis=where(:date=>date, :name=> DATA["no-points"].keys).all().map {|x| x.ini}
    #find slide activities with non specialist
    m=where(:date=>date, :name=> {:$nin=>DATA["slide_activities"]}, :ini=>p_inis).all
    return ((m.map{|x| x.tot_points}.reduce(:+)) or 0)
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
    m=where(:date=>date, :name=> DATA["slide_activities"],:ini=> {:$nin=>p}).all

    return ((m.map {|x| x.n}.reduce(:+)) or 0)
    #.map{|x| x.n}.reduce(:+)

  end

  def update_tot_points
      self.tot_points=self.points*self.n
  end
end


#index activities
Activity.ensure_index([[:date, -1], [:pathologist_id, 1], [:name,1]])





