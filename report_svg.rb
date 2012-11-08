my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


#require "statsample"
require "web_data"
#require 'rserve'
require "redis"
require "redis-namespace"
require 'pony'
require "csv"
require 'rserve/simpler'
require "report_data"


def r_connect
  $r=Rserve::Simpler.new
  display=ENV["DISPLAY"]
  $r.command ("X11(display='#{display}')")
  $r.command ("library('ggplot2')")
  puts $r.eval ("capabilities()").to_s
end





def r_boxplot data
  temp_file=Tempfile.new "boxplot-pdf"

  $r.assign "raw_data", data
  $r.eval "boxplot(raw_data)"
  $r.eval "dev.copy(png,'#{temp_file.path}')"
  $r.eval "dev.off()"
  temp_file_data=File.read temp_file.path
  temp_file.unlink
  temp_file_data
end




def rify_hash hash_frame

  puts "data.frame(x=#{rify_list hash_frame.keys}, y=#{rify_list hash_frame.values})"

end



def rify_list data_list
  "c(#{data_list.to_json})".gsub("[","").gsub("]","").gsub(":","")
end

def rify_mongomapper mongo_mapper_class
  $d=CSV.generate do |csv|
    keys=mongo_mapper_class.keys.keys
    csv << keys
    mongo_mapper_class.all.each do |a|
      temp=[]
      keys.each do |k|
        temp << a.send(k)
      end
      csv<<temp
    end
  end
  t=Tempfile.new "#{mongo_mapper_class}"
  t.write $d
  t.close
  t.path
end


####Superclass For plotSVG engines
#
# Implements some basic methods related to redis
class PlotterRedis
  attr_accessor :redis_name_spaced
  #redis expiration set at 15 days  24*360*15
  @@expire=129600

  #Redis namespace
  #
  # Example:
  #
  #r['foo'] = 1000
  #This will perform the equivalent of:
  #redis-cli set ns:foo 1000
  def get_redis_name_spaced name_space
    #checks global testing and if true introduces separate namespacing
    if $redis_testing
      Redis::Namespace.new("testing_"+name_space, :redis =>$redis)
    else
      Redis::Namespace.new(name_space, :redis =>$redis)
    end
  end

  def get redis_key
    @redis_name_spaced.get redis_key
  end

  def del redis_key
    @redis_name_spaced.del redis_key
  end

  def get_by_n n
    redis_key= (get_business_utc n).to_date.to_s 
    redis_name_spaced.get redis_key
  end

  def clean
    @redis_name_spaced.keys.each do |key|
      @redis_name_spaced.del key
    end
  end

  #plots in R and returns SVG data
  # input is a hash with simple keys value mapping;  Keys are x, values are Y of the plot
  def bar_plot data
    if data==false then return false end
    hash_frame={}
    hash_frame["ini"]=data.keys.map{|x| x.to_s}
    hash_frame["deviation_from_mean_points"]=data.values
    puts "hash_frame", hash_frame
    #tempfile is used to save SVG output. This is then unlinked. 
    t=Tempfile.new ["svg-file",".svg"]
    $r.command( df: hash_frame.to_dataframe ) do
      <<-EOF
      ggplot(data=df, aes(ini,deviation_from_mean_points))+geom_bar()+coord_flip()+ scale_y_continuous(name="Deviation from mean total points distribution")+scale_x_discrete(name="")
      ggsave("#{t.path}")
      EOF
    end
    results=File.read(t.path)
    t.unlink
    return results
  end
end

#### Plotting Engine
#
#
class PlotterDeltaDay <PlotterRedis


  def initialize 
    @redis_name_spaced=get_redis_name_spaced "day_distribution"
  end
  
  #Plots graph from days work
  #
  # Input [{:SZ=>-79,
  #:JS=>-78,
  #:SEK=>-5
  #
  # Output is plot
  def plot (n)
    redis_key= (get_business_utc n).to_date.to_s 
    #check if already existing already existing
    return redis_key unless @redis_name_spaced.get(redis_key) ==nil
    puts "making graph and storing it in redis name spaced"
    #this is the data structure that gets converted into R
    hash_frame={}
    data=Deviation.for_day n
    if data==false then return false end
    @redis_name_spaced.set redis_key, bar_plot(data)
    #set to expire at 
    @redis_name_spaced.expire redis_key, @@expire
    redis_key
  end
end


class PlotterDeltaSummary <PlotterRedis

  def initialize
   @redis_name_spaced=get_redis_name_spaced "delta_summary"
  end

  def plot
    #key is today's date
    redis_key= (get_business_utc 0).to_date.to_s 
    #check if already existing already existing
    return redis_key unless @redis_name_spaced.get(redis_key) ==nil
    puts "making graph and storing it in redis name spaced"
    data=Deviation.sum_deviation(Deviation.deviation_all)
    @redis_name_spaced.set redis_key, bar_plot(data)
    @redis_name_spaced.expire redis_key, @@expire
    return redis_key      

  end
end


def delta_day
  r={}
  DATA["initials"].map{|x|x.to_sym}.each do |k|
   r[k]= Actity.find_by_ini(k).map{|x| x.tot_points}
  end
  r
end

class BoxPlotDistDelta <PlotterRedis
  
  def initialize
   @redis_name_spaced=get_redis_name_spaced self.class.to_s
  end

  def plot
     #key is today's date
    redis_key= (get_business_utc 0).to_date.to_s 
    #check if already existing already existing
    return redis_key unless @redis_name_spaced.get(redis_key) ==nil
    puts "making graph and storing it in redis name spaced"
    data=Deviation.deviation_all

  end
end

