require "mongo_mapper"
require "pp"

#Configuration
#-------------
DATA_BASENAME='mongomapperbonanza'
DATA_FILE="./base_line_data.yml"
MongoMapper.database = DATA_BASENAME
DATA=YAML.load File.read DATA_FILE


#Total Daily Cases
class Tdc
  include MongoMapper::Document
  safe
  key :pathologists, Array
  many :pathologist, :in => :pathologists #objects are in pathologist; ids in pathologists
  key :blocks_west, Integer, :default=>0
  key :blocks_east, Integer, :default=>0
  key :tot_points, Integer, :default=>0
  key :extra_points_tot, Integer, :default=>0
  key :tot_points_pathologist, Integer, :default=>0
  #Date.today.to_time.utc
  #Tdc.where(:date=>Date.today.to_time.utc).to_a
  key :date, Time, :default=>Date.today.to_time.utc


  #returns only one Tdc
  def self.today
    d=where(:date=>Date.today.to_time.utc)
    if d.count>0 then d.to_a[0] else Tdc.new end
  end

  #only todays match
  def self.get_path ini
    self.today.pathologist.select {|x| x.ini==ini}
  end
end


module TodaySet
  def set_path_off ini
    p=self.get_path_by_ini ini
    p.working=false
    p.save
  end

  def set_blocks_west n
    t=Tdc.today
    t.blocks_west=n
    t.save
    puts "blocks west #{t.blocks_west}"
  end

  def set_blocks_east n
    t=Tdc.today
    t.blocks_east=n
    t.save
    puts "blocks eats #{t.blocks_east}"
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


module TodayGet

  def get_path_all
    t=Tdc.today
    t.pathologist
  end
   #magic souce formula....
  def get_points_slide_tot
     t=Tdc.today
     total_slide_points= 1.2 * (t.blocks_west+t.blocks_east)
     total_slide_points.to_int
  end
  def get_points_tot
    t=Tdc.today
    puts "Slides:#{self.get_points_slide_tot()};Activity: #{Activity.get_activity_points } "
    t.tot_points=(self.get_points_slide_tot() + Activity.get_activity_points)
    puts t.tot_points
    return t.tot_points
  end

  def get_path_working
    t=Tdc.today
    t.pathologist.select {|x| x.working==true}
  end

  def get_path_absent
    t=Tdc.today
    t.pathologist.select {|x| x.working==false}.map {|x| x.ini}
  end

  def get_path_by_ini ini
    t=Tdc.today
    p=t.pathologist.select {|x| x.ini==ini}
    p[0] if p.count>0
  end

  def get_path_by_id _id
    t=Tdc.today
    p=t.pathologist.select {|x| x._id==_id}
    p[0] if p.count>0
  end
end


class Today
  include TodaySet
  include TodayGet

  def initialize
    @all_activities_points= DATA["regular_activities"].merge DATA["cardinal_activities"]
  end


  # all paths for the day

  def get_setup
    if self.get_path_working.count==0 then populate end
    t=Tdc.today
    tot_points=self.get_points_tot();blocks_tot=t.blocks_west+t.blocks_east; slide_points=blocks_tot*1.2; activity_points=tot_points-slide_points
    pathologist_working=self.get_path_working.map { |x| x.ini }
    path_count= self.get_path_working.count
    setup={blocks_west: t.blocks_west,
          blocks_east: t.blocks_east,
          blocks_tot: t.blocks_west+t.blocks_east,
          tot_points: tot_points,
          slide_points: slide_points,
          activity_points: activity_points,
          pathologist_all: self.get_path_all.map { |x| x.ini  },
          pathologist_working: (pathologist_working).sort,
          pathologist_absent: (self.get_path_absent).sort,
          path_count: path_count,
          date: Date.today.to_s}
    setup[:points_per_pathologist]=  self.points_per_path
    return setup
  end

  def points_per_path
    tot_points=self.get_points_tot()
    path_count= self.get_path_working.count
    tot_points/path_count if path_count !=0
  end

  def set_setup params
    puts " params is #{params}; and has key #{params.has_key? 'blocks_east'}"
    self.set_blocks_east params['blocks_east'] #unless (not (params.has_key? 'blocks_east'))
    self.set_blocks_west params['blocks_west'] #unless (not (params.has_key? 'blocks_west'))
    self.set_present(params['path_present']) unless (not (params.has_key? 'path_present'))
    self.set_absent(params['path_absent']) unless (not (params.has_key? 'path_absent'))
    return true
  end

  def get_entry
    if self.get_path_working.count==0 then populate end
    entry={pathologist_working: self.get_path_working.map { |x| x.ini}.sort(),
      paths_acts_points: Pathologist.all_activities_points,
      paths_tot_points: Pathologist.path_all_points
     }
  end

  def set_regular path_ini, activity_name, n
    p=self.get_path_by_ini path_ini
    existing_activities=p.activities.map{|x| x.name}
    if existing_activities.member? activity_name then a=Activity.get_ini_name(path_ini,activity_name) else a=Activity.new  end
    a.name=activity_name
    if @all_activities_points.has_key? activity_name then a.points=@all_activities_points[activity_name] else return false end
    a.n=n
    p.activities<<a
    a.save
    p.save
    pp "just updated for you #{path_ini}'s #{a.name} to a number of #{a.n} and tot_points of #{a.tot_points} "
  end

  def set_cardinal path_ini, on_array
    p=self.get_path_by_ini path_ini; existing_activities=p.activities.map{|x| x.name}
    off_array=DATA["cardinal_activities"].keys.select{|x| not (on_array.member? x)}
    puts "on: #{on_array}; not on #{off_array}"
    on_array.each do |activity_name|
      if existing_activities.member? activity_name then a=Activity.get_ini_name(path_ini,activity_name) else a=Activity.new  end
      if @all_activities_points.has_key? activity_name then a.points=@all_activities_points[activity_name] else return false end
      a.n=1
      a.name=activity_name
      p.activities<<a
      a.save
      p.save
    end
    off_array.each do |activity_name|
      a=Activity.get_ini_name(path_ini,activity_name)
      a.delete if a
    end
  end
end


class Pathologist
  include MongoMapper::Document
  safe
  belongs_to :tdc
  key :ini, String #intials
  key :site, String
  key :date, Time, :default=>Date.today.to_time.utc
  key :working, Boolean, :default=>true
  many :activities
  def self.today
    d=where(:date=>Date.today.to_time.utc)
    d.to_a if d
  end
  def self.by_ini ini #only today
    d=self.today.select{|x| x.ini==ini}
    d[0] if d.count >0
  end
  def self.get_path_working
    d=where(:working=>true, :date=>Date.today.to_time.utc)
    d.to_a if d
  end
  def self.path_all_points
    points_per_path=Today.new.points_per_path
    path_all_points=[]
    self.get_path_working.each do |x|
      path_all_points<<{tot: x.total_points, ini: x.ini, range: points_per_path}
    end
    path_all_points.sort_by {|x| x[:ini]}
  end
  def self.all_paths
    DATA["initials"]
  end
  def self.all_activities_points
    r={}
    self.get_path_working.each {|x| r[x.ini]=x.activities_points}
    return r
  end
  def activities_points

    activities_points={}
    self.activities.each {|x| activities_points[x['name']]={tot_points: x['tot_points'],
                                                            n: x[:n]}}
    activities_points
  end
  def total_points
    self.activities.map{|x| x.tot_points}.reduce(:+) or 0
  end
end


class Activity
  include MongoMapper::Document
  safe
  key :name, String
  key :n,Integer, :default=>0
  key :points, Integer, :default=>0
  key :date, Time, :default=>Date.today.to_time.utc
  key :tot_points, Integer
  belongs_to :pathologist
  before_save :update_tot_points
  before_update :update_tot_points

  def self.today
    d=where(:date=>Date.today.to_time.utc)
    d.to_a if d
  end

  def self.get_ini_name path_ini,activity_name
    path_id=Today.new.get_path_by_ini(path_ini)._id
    puts path_id
    d=where(:date=>Date.today.to_time.utc, :pathologist_id=>path_id, :name=>activity_name)
    d=d.to_a if d
    if d.count >0 then return  d[0] else return false end 
  end

  def self.all_activities
    DATA["regular_activities"].merge DATA["cardinal_activities"]
  end

  def self.get_activity_points
    t=Today.new
    x=0
    self.today.each do |a|
      #check if activity in sont a slide and that the path is working
      if ((DATA["slide_activities"].member? a.name) and (t.get_path_by_id a.pathologist_id).working)then next end
      if (t.get_path_by_id a.pathologist_id).working then x+=a.tot_points else a.destroy end
    end
    return x
  end

  def update_tot_points
      self.tot_points=self.points*self.n
  end
end

#### Utilities

def all_paths
  DATA["initials"]
end

def populate
  t=Tdc.today
  all_paths.each {|ini| t.pathologist<<Pathologist.new({:ini=>ini})}
  t.save
end

def random_assign_activity act,points,n
  a=Activity.new
  a.name=act
  a.points=points
  a.n=n
  p=Pathologist.today.sample
  p.activities<<a
  a.save
  p.save
  pp p .activities
end

def simulate
  populate
  t=Today.new
  t.set_blocks_east [444,200,100].sample
  t.set_blocks_west [344,400,233].sample
  all_activities=DATA["regular_activities"].merge DATA["cardinal_activities"]
  DATA["regular_activities"].each do |act,points|
    random_assign_activity act, points, [1,2,3,4,5,6,7,8,9,10].sample()
  end
  DATA["cardinal_activities"].each do |act,points|
    random_assign_activity act, points, 1
  end
  pp Pathologist.all_activities_points
end

#setting up the entry for only 2 pathologist
def test_2
  clean
  populate
  Pathologist.today.each do |p|
    puts "#{p.ini} #{p.ini=='CBB'} " 
    if (p.ini=="CBB" or p.ini=="SW") then  puts "CBB"; next end
    p.working=false
    p.save
  end
  Pathologist.today()
end

def todays_work
  t=Today.new
  t.set_blocks_east [232,333,555].sample
  t.set_blocks_west [444,555,666].sample
  pathologist_work={}
  Pathologist.today.each do |p|
    pathologist_work[p.ini]=[]
    p.activities.each do |a|
      pathologist_work[p.ini]<<{name: a.name,points: a.points, tot_points: a.tot_points, fac: a.n}
   end

  end

  return pathologist_work #.to_json
end

def clean
  Tdc.delete_all
  Activity.delete_all
  Pathologist.delete_all
end