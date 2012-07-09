require "mongo_mapper"

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
end


class Today
  include TodaySet
  include TodayGet


  def set_path_on ini
    p=self.get_path_by_ini ini
    p.working=true
    p.save
  end

  def set_present ini_array
    ini_array.each {|ini| self.set_path_on ini}
  end

  def set_absent ini_array
    ini_array.each {|ini|  self.set_path_off ini}
  end


  # all paths for the day

  def get_setup
    if self.get_path_working.count==0 then populate end
    t=Tdc.today
    tot_points=self.get_points_tot()
    pathologist_working=self.get_path_working.map { |x| x.ini }
    path_count= self.get_path_working.count
    setup={blocks_west: t.blocks_west,
          blocks_east: t.blocks_east,
          blocks_tot: t.blocks_west+t.blocks_east,
          tot_points: tot_points,
          pathologist_all: self.get_path_all.map { |x| x.ini  },
          pathologist_working: (pathologist_working).sort,
          pathologist_absent: (self.get_path_absent).sort,
          path_count: path_count,
          date: Date.today.to_s}
    setup[:points_per_pathologist]=  tot_points/path_count if path_count !=0
    return setup
  end

  def set_setup params
    puts " params is #{params}; and has key #{params.has_key? 'blocks_east'}"
    self.set_blocks_east params['blocks_east'] #unless (not (params.has_key? 'blocks_east'))
    self.set_blocks_west params['blocks_west'] #unless (not (params.has_key? 'blocks_west'))
    self.set_present(params['path_present']) unless (not (params.has_key? 'path_present'))
    self.set_absent(params['path_absent']) unless (not (params.has_key? 'path_absent'))
    return true
  end


  def get_points_per_path
    t=Tdc.today
    tot_points=t.blocks_west+t.blocks_east+Activity.get_activity_points
    n_pathologist=self.get_path_working.count
    if n_pathologist >0
      then return tot_points/n_pathologist
    else
      return nil
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

  def self.get_activity_points
    x=0
    self.today.each do |a|
      x+=a.tot_points
    end
    return x
  end

  def update_tot_points
      self.tot_points=self.points*self.n
  end
end

def all_paths
  DATA["sv_initials"]+DATA["ppmc_initials"]
end

def populate
  t=Tdc.today
  all_paths.each {|ini| t.pathologist<<Pathologist.new({:ini=>ini})}
  t.save
end

def random_assign_activity act,points
  a=Activity.new
  a.name=act
  a.points=points
  a.n=[1,2,3,4,5].sample()
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
  all_activities=DATA["sv_regular_activities"].merge DATA["sv_cardinal_activities"]
  all_activities.each do |act,points|
    random_assign_activity act, points
  end
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