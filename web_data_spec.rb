my_directory=File.dirname(File.expand_path(__FILE__))
#$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory
require 'web_data'


describe Tdc do
  it "saves" do
    t=Tdc.new
    t.sv_tot=33
    t.ppmc_tot=2
    t.all_tot=t.sv_tot+t.ppmc_tot
    t.tot_points_pathologist=0
    t.absent_ppmc=[]
    t.absent_sv=[]
    t.save
  end
  it "finds" do
      Tdc.all.count.should==1
      Tdc.find_one.sv_tot.should==33
      Tdc.today.date.should==Date.today.to_time.utc
  end
  it "persists" do
    t=Tdc.new
    t.sv_tot=33
    t.ppmc_tot=2
    t.all_tot=t.sv_tot+t.ppmc_tot
    t.tot_points_pathologist=0
    t.absent_ppmc=[]
    t.absent_sv=[]
    t.date=Date.today.to_time.utc
    t.save
    Tdc.all.count.should==2
  end
  it "has many pathologist" do
    t=Tdc.new
    p0=Pathologist.new
    p0.ini="CBB"
    p1=Pathologist.new
    p1.ini="MM"
    t.pathologist<<p0
    t.pathologist<<p1
    t.pathologists.count.should==2
  end
end

describe Activity do
  x=YAML.load File.read "base_line_data.yml"
  it "can be many" do
    x["sv_regular_activities"].each do |key,value| 
      a=Activity.new
      a.name=key
      a.points=value
      a.save
    end
    #puts "HELLO #{Activity.all}"
  end
  it "can do a today" do
    Activity.today.length.should==Activity.all.length
  end
end

describe Pathologist do
  initials=(YAML.load File.read "base_line_data.yml")["ppmc_initials"]
  it "can be many" do
    initials.each do |ini|
      p=Pathologist.new
      p.ini=ini
      p.save
    end
  end
  it "can do a today" do
    Pathologist.today.length.should==Pathologist.all.length
  end
  it "can have many activities" do
    p=Pathologist.new
    p.ini="CBB"
    a=Activity.new
    a.pathologist=p
    p.activities<<a
    a.save
    p.save
    a1=Activity.new
    a1.pathologist=p
    p.activities<<a1
    a1.save
    p.save
    pp p.activities
  end
end






