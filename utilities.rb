####Loading paths
#libs for the generation of the DOT Files
#add the current dir  and lib to the load path
my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory

require "web_data"
require 'business_time'




#### Utilities


def populate n=0, number_of_path=DATA["initials"].count
  date=(Date.today+n)
  t=Tdc.today n
   DATA["initials"].sample(number_of_path).each do |ini|
    if not Pathologist.where({:ini=>ini,:date=>date.to_time.utc}).any?
      t.pathologist<<Pathologist.new({:ini=>ini,:date=>date.to_time.utc})
      puts "#{ini} created"
    else
      puts "#{ini} already existing"
    end
  end
  t.save
end

def sim_2 n
  switch_to_testing
  clean
  t=Tdc.today n
  all_p=Pathologist.get_all_path(n)
  (all_p.count-3).times do |x|
    p=all_p[x]
    p.working=false
    p.save
  end
end


def create_activity day,act,points,n,p
  a=Activity.new;
  a.name=act
  if DATA["distribution-specialty"].keys.include? a.name
    p.specialty_only=true
    p.update_specialty_status a.name
  end
  a.points=points
  a.n=n
  a.ini=p.ini
  a.date=(Date.today+day).to_time.utc
  a.save
  p.activities<<a
  p.save
end

def working_n n
   # @ n is the number of days after today; needs to tak into accound weekends/holidays
  if n< 0
    return (((1*-n).business_day.before Date.today).to_date - Date.today).to_int
  else
    (((1*n).business_day.after Date.today).to_date - Date.today).to_int
  end
end

def simulate n=0
  n= working_n n
  populate n
  t=Today.new n
  #t.set_blocks_east [444,200,100].sample
  #t.set_blocks_west [344,400,233].sample
  all_activities=DATA["regular_activities"].merge DATA["cardinal_activities"]
  DATA["regular_activities"].each do |act,points|
    p=(t.tdc.pathologist).sample
    create_activity n,act, points, [1,2,3,4,5,6,7,8,9,10].sample(),p
  end
  DATA["cardinal_activities"].each do |act,points|
    p=(t.tdc.pathologist).sample
    create_activity n,act, points, 1,p
  end
  DATA["slide_activities"].each do |a|
    (t.tdc.pathologist).each do |p|
      create_activity n,a,1,[20,40,30,23,60,79].sample,p
    end
  end
  tdc=Tdc.today n
  tdc.blocks_tot=[500,300,600].sample
  tdc.total_GI=[50,60,30].sample
  tdc.total_SO=[50,60,30].sample
  tdc.total_ESD=[50,60,30].sample
  tdc.total_cytology=[50,60,30].sample
  tdc.left_over_previous_day_slides=[50,60,30].sample
  tdc.save

  pp Pathologist.all_activities_points n
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

def prompt(*args)
    print(*args)
    gets.strip
end


def clean
  if prompt("Are you sure you want to clean all of #{ MongoMapper.database.name } database??? yes/no: ") =="yes"
    Tdc.delete_all
    Activity.delete_all
    Pathologist.delete_all
    puts " YOU HAVE A CLEAN DATABASE"
  else
    puts "CANNOT CLEAN A PRODUCTION SETTING..."
  end
end

def to_production message
  puts `git commit -am #{message}`
  Dir.chdir "../path-tracker-deploy"
  puts `git pull`
   Dir.chdir "../path-tracker"
   `sudo cp ~/Dropbox/code/path-tracker/plist/* /Library/LaunchDaemons/`
end

def tail n=100
  puts `tail -n #{n} /var/log/path-tracker/path-tracker.log`

end



