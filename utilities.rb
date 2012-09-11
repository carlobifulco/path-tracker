#libs for the generation of the DOT Files
#add the current dir  and lib to the load path
my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory

require "web_data"

def random_assign_activity act,points,n
  a=Activity.new; p=Pathologist.today.sample
  a.name=act
  a.points=points
  a.n=n
  a.ini=p.ini
  p.activities<<a
  a.save
  p.save
  pp p.activities
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


def simulate_x x
  x.times do |i|
    simulate
  end
end

#setting up the entry for only 2 pathologist
def test_2
  clean
  populate
  Pathologist.today.each do |p|
    puts "#{p.ini} #{p.ini=='CBB'} "
    if (p.ini=="CBB" or p.ini=="SW")
      next
    else
      p.working=false
      p.save
    end
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