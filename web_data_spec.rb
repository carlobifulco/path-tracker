my_directory=File.dirname(File.expand_path(__FILE__))
#$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory

require 'web_data'

#override default configuration
#Configuration
#-------------
DATA_BASENAME='mongomapperrespec'
DATA_FILE="./base_line_data.yml"
MongoMapper.database = DATA_BASENAME



describe Tdc do
  it "saves" do
    t=Tdc.new
    t.blocks_east=33
    t.blocks_west=2
    t.tot_points=t.blocks_east+t.blocks_west
    t.save
  end
  it "finds" do
      Tdc.all.count.should==1
      Tdc.find_one.blocks_east.should==33
      Tdc.today.date.should==Date.today.to_time.utc
  end
  it "persists" do
    t=Tdc.new
    t.blocks_east=33
    t.blocks_west=2
    t.tot_points=0
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
    x["regular_activities"].each do |key,value|
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
  initials=(YAML.load File.read "base_line_data.yml")["initials"]
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

# blank slate database
clean




