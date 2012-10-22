my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


require "statsample"
require "web_data"
require 'rserve'
require "redis"
require 'pony'

$r=Rserve::Connection.new

#Redis configutation
# :password=>"redisreallysucks",
$redis=Redis.new(:thread_safe=>true,:port=>6379,:host=>$HOST)
# Redis table
UseDb=1
ConfigurationDb=2
$redis.select ConfigurationDb


#configuration parameters live in the configuration table
module Setup

  def check_redis()
    $redis.select ConfigurationDb
    begin
      if ($redis.get "liame") == nil then raise "EMAIL MISSING" end
    rescue
      puts "email missing"
      raise "EMAIL MISSING"
    end
    $redis.select UseDb
  end

  def configuration &block
    $redis.select ConfigurationDb
    r=block.call
    $redis.select UseDb
    r
  end

 def configuration_set(key,text)
    configuration do
       $redis.set key,text
    end
 end

 def configuration_get(key)
   configuration do
    result=$redis.get key
   result
  end
 end

 # reset all UseTable
 def clean_redis (a=[])
  $redis.select UseDb
   r=[]
   $redis.keys.each do |k|
     r << ($redis.del k)
   end
   configuration_set "on", "off"
   r
 end
end

class Email
  include Setup
  #include Html
  def email (text_string="HELLO FROM PONY", email_addresses=["carlobif@gmail.com"])#,"Sidney.Rosenheim@providence.org"
    email_addresses.each do |email_address|
      Pony.mail(:to => email_address,
        :via => :smtp,
        :from => "carlobifulco@providence.org",
        :sender=>"carlobifulco@providence.org",
        :via_options => {
          :address => 'smtp.gmail.com',
          :port => '587',
          :enable_starttls_auto => true,
          :user_name => 'distributionemailer@gmail.com',
          :password => configuration_get("liame"), #"work1234"
          :authentication => :plain, # :plain, :login, :cram_md5, no auth by default
          :domain => "HELO", # don't know exactly what should be here
          },
      :subject => 'distribution', :body => text_string, :html_body => "<h1>HELLO</h1>")
    end
  end

  def test
    configuration_get "liame"
  end
end



def reduce_points_by_day activity_search_results_array
  activity_hash={}
  # creates this data structure
  #{2012-10-03 07:00:00 UTC=>[12], 2012-10-11 07:00:00 UTC=>[60, 30]}
  activity_search_results_array.each do |a|
    activity_hash[a.date]=[] unless activity_hash.has_key? a.date
    activity_hash[a.date]<<a.tot_points
  end
  puts activity_hash
  activity_hash.map{|k,v| v.reduce(:+)}
end

def report_activity_points activity_name
  reduce_points_by_day (Activity.where :name => activity_name).all
end

def report_activity_points_for_subspecialty activity_name, subspecialty
  reduce_points_by_day (Activity.where :name => activity_name).all.select{|x| x.has_path_subspecialty? subspecialty}
end

def report_activity_points_for_pathologist activity_name, path_ini
 reduce_points_by_day (Activity.where :name => activity_name).all.select{|x| x.ini ==path_ini}
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

def report_deviation_from_mean_data n
  t=Tdc.today n
  deviation_from_mean=[]
  points= {:specialty_non_slide_points => Activity.get_specialist_non_slide_points(t.n),
              :specialty_slide_points => Activity.get_specialist_slides_distributed(t.n),
              :general_non_slide_points => Activity.get_general_non_slide_points(t.n),
              :general_slides_distributed => Activity.get_general_slides_distributed(t.n)}
  tot_general_points=points[:general_non_slide_points]+points[:general_slides_distributed]
  average_generalist_points=tot_general_points/Pathologist.get_number_generalist(n)
  Pathologist.get_generalist(n).each do |p|
    deviation_from_mean << (average_generalist_points-p.total_points)
  end
  deviation_from_mean

end


def report_day n
  text=[]
  t=Tdc.today n
  points= {:specialty_non_slide_points => Activity.get_specialist_non_slide_points(n),
            :specialty_slide_points => Activity.get_specialist_slides_distributed(n),
            :general_non_slide_points => Activity.get_general_non_slide_points(n),
            :general_slides_distributed => Activity.get_general_slides_distributed(n)}
  tot_points=points.values.reduce(:+)
  tot_general_points=points[:general_non_slide_points]+points[:general_slides_distributed]
  average_generalist_points=tot_general_points/Pathologist.get_number_generalist(n)

  text << "Day #{get_business_utc(n)}"
  text << "**************"
  text << "\t- Total System non-slide points assigned: #{points[:specialty_non_slide_points]+points[:general_non_slide_points]}"
  text <<  "\t- Total Generalist non-slide points assigned #{points[:general_non_slide_points]}"
  text << "\t- Total Specialist non-slide points assigned #{points[:specialty_non_slide_points]}"
  text << "\t- Predicted slides to be distributed: #{t.get_predicted_points_slide_tot}"
  text << "\t- Total Generalist slides distributed: #{points[:general_slides_distributed]}"
  text << "\t- Ratio generalist slides distributed/blocks =#{points[:general_slides_distributed]/t.blocks_tot.to_f unless t.blocks_tot==0 }"
  text << "\t- Diff slides predicted vs distributed: #{t.get_predicted_points_slide_tot- points[:general_slides_distributed]}"
  # puts "\t- Average (mean) theoretical workload per generalist Pathologist: #{Activity.get_general_non_slide_points+Activity.get_general_slides_distributed/Pathologist.get_number_generalist}"
  text << "\t- Average (mean) effective total points workload per generalist Pathologist: #{average_generalist_points}"
  text << "*************"
  text << "Generalist Points Distribution:"
  text <<"*************"
  Pathologist.get_generalist(n).each do |p|
    text << "\tDeviation from mean for #{p.ini}: #{-(average_generalist_points-p.total_points)}"
  end
  return text.join "\n"
end


def get_day_summary date
  t=Tdc.find_by_date date
  if t
    points= {:specialty_non_slide_points => Activity.get_specialist_non_slide_points(t.n),
              :specialty_slide_points => Activity.get_specialist_slides_distributed(t.n),
              :general_non_slide_points => Activity.get_general_non_slide_points(t.n),
              :general_slides_distributed => Activity.get_general_slides_distributed(t.n)}
    points[:tot_points]=points.values.reduce(:+)
    points[:tot_general_points]=points[:general_non_slide_points]+points[:general_slides_distributed]
    points[:average_generalist_points]=points[:tot_general_points]/(Pathologist.get_number_generalist t.n)
    generalist_dev={}
    Pathologist.get_generalist(t.n).each do |p|
      generalist_dev[p.ini.to_sym] = - (points[:average_generalist_points] - p.total_points)
    end
    points[:generalist_dev]=generalist_dev
    return points
  else
    return false
  end
end

# Summary per pathologist of delta in points distribution across n day
#
# n is the number of days in the past
#
# Returns a list containing  dictionaries of pathologist=>tot_deviation
#
# => [{:JAO=>-1, :JS=>-1, :SEK=>-1,

def points_deviation_list_for_generalist n
  dev_list=[]
  (-n..0).each do |x|
    day_summary=get_day_summary(get_business_utc x)
    #ensure that there is data
    if day_summary
      dev_list<<day_summary [:generalist_dev]
    # enter 0 if no data
    else
      dev_list<<false
    end
  end
  dev_list
end

# Eats a points deviation list and spits  {:SEK=>[-1, -10],:JAO=>[-1, -9, -10],
# Then reduces the list component
# to > {:SEK=>-11, :JAO=>-20
def get_sum_points_deviation points_deviation_list
  sum_points_deviation={}
  #flip over paths;  -1 because that is date n=0
  points_deviation_list[-1].keys.each do |k|
    #creates a new container array
    sum_points_deviation[k]=[]
    points_deviation_list.each do |l|
      #and fills it up after rotating on each dictionary by matching entry
      if l.has_key? k then sum_points_deviation[k]<<l[k] end
    end
    #now reduce
    puts sum_points_deviation[k] = (sum_points_deviation[k]).reduce(:+)
  end
  return sum_points_deviation
end






