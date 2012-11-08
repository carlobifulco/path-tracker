my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


require "mongo_mapper"
require "pp"
require "utilities"

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
  key :date, Time


  #returns only one Tdc
  def self.today
    d=where(:date=>Date.today.to_time.utc)
    if d.to_a.count>0 
      return d.to_a[0] 
    else 
      t=Tdc.new
      t.date=Date.today.to_time.utc
      t.save 
      return t
    end
  end

  #only todays match
  def self.get_path ini
    self.today.pathologist.select {|x| x.ini==ini}
  end
end

#index Tdc
Tdc.ensure_index(:date)


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
    #populates if day is empty
    t=Tdc.today
    if t.pathologists.count==0 then populate end
    tot_points=self.get_points_tot();blocks_tot=t.blocks_west+t.blocks_east; slide_points=(blocks_tot*1.2).to_i; activity_points=tot_points-slide_points
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
    t=Tdc.today
    puts " params is #{params}; and has key #{params.has_key? 'blocks_east'}"
    self.set_blocks_east params['blocks_east'] #unless (not (params.has_key? 'blocks_east'))
    self.set_blocks_west params['blocks_west'] #unless (not (params.has_key? 'blocks_west'))
    self.set_present(params['path_present']) unless (not (params.has_key? 'path_present'))
    self.set_absent(params['path_absent']) unless (not (params.has_key? 'path_absent'))
    return true
  end

  def get_entry
     #populates if day is empty
    t=Tdc.today
    entry={pathologist_working: self.get_path_working.map { |x| x.ini}.sort(),
      paths_acts_points: Pathologist.all_activities_points,
      paths_tot_points: Pathologist.path_all_points
     }
  end

  def set_regular path_ini, activity_name, n
    p=self.get_path_by_ini path_ini
    existing_activities=p.activities.map{|x| x.name}
    #get if existing else new
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
  key :date, Time
  key :working, Boolean, :default=>true
  many :activities
  # important  --remove activity if path is at home...
  after_update :delete_activities_if_not_working
  #before create check that is not alreaay there
  # validate :already_there

  # def already_there
  #   d=Pathologist.where(:date=>Date.today.to_time.utc, :ini=>self.ini)
  #   if d.to_a.count>0
  #     errors.add( :ini, "Already there")
  #   end
  # end

  def self.today
    d=where(:date=>Date.today.to_time.utc)
    d.to_a if d
  end


  def delete_activities_if_not_working
    puts "#{self} getting called"
    if not self.working
      puts "deleting"
      (Activity.find_all_by_pathologist_id  self._id).each do |a| 
        puts "deleting #{a}"
        a.delete
      end
    end
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


  #all activities points unless slide related
  def self.get_activity_points
    slide_activities=DATA["slide_activities"]; x=0
    self.today.each do |a|
       x+=a.tot_points unless slide_activities.member? a.name
    end  
    x
  end



  def update_tot_points
      self.tot_points=self.points*self.n
  end
end


#index activities
Activity.ensure_index([[:date, -1], [:pathologist_id, 1], [:name,1]])


#### Utilities

def all_paths
  DATA["initials"]
end

def populate
  t=Tdc.today
  all_paths.each {|ini| t.pathologist<<Pathologist.new({:ini=>ini,:date=>Date.today.to_time.utc})}
  t.save
end

