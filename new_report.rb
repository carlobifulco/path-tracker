my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory



require "web_data"
require 'rufus/scheduler'
require 'statsample'



class DayReport
  include MongoMapper::Document
  safe
  key :all_gi, Integer
  key :all_heme, Integer
  key :all_derm, Integer
  key :all_general, Integer
  key :all_cytology, Integer
  key :slides_blocks_ratio, Float
  key :left_over_previous_day_slides, Integer
  key :date, Time
  key :pathologist_working, Integer
  key :general_day_points_hash, String #json of an hash
  key :general_day_points_tot, Integer
  key :general_day_points_mean, Float
  key :general_day_points_sd, Float

  #before_save :write_date

  def write_date
    puts "getting called"
    self.date=get_business_utc 0
  end
end

DayReport.ensure_index([[:date, -1],])


#
class SetupReport

  attr_accessor :r, :tdc, :pc

  def initialize n=0
    @n=n
    @tdc=Tdc.today(n)
    @pc=PointsCalculator.new(n)
    @r={}
  end

  def get_left_over_previous_day_slides n=0
    @tdc.left_over_previous_day_slides
  end

  def get_general_slides_blocks_ratio

    distributed_general_slides=SpecialtyReport.all_general(@n).tot_points
    all_blocks=(@tdc.blocks_tot-@tdc.total_GI-@tdc.total_SO-@tdc.total_ESD)
    if distributed_general_slides==nil then return false end
    if all_blocks==0 then return false end
    return distributed_general_slides/all_blocks.to_f

  end

  def get_pathologist_working
    @tdc.get_working.count
  end
end

class DistReport

  attr_accessor :r, :tdc, :pc, :all, :all_sum, :tot_each, :vector

  def initialize n=0
    @n=n
    @tdc=Tdc.today(n)
    @pc=PointsCalculator.new(n)
    @r={}
    @all=(Activity.where :date=>get_business_utc(n),:specialty_only =>false).all.map {|x| {x.ini=> x}}

    @all_sum={}
    @all.each do |x|
      ini= x.keys[0]
      @all_sum[ini.to_sym]=[] unless @all_sum.has_key? ini.to_sym
      @all_sum[ini.to_sym]<<x[ini]
    tot_each
    make_vector
    end
  end

  def tot_each
    @tot_each=@all_sum.map {|k,v| {k=>v.map{|x| x.tot_points}.reduce(:+)}}
  end

  def general_day_points_tot
    @tot_each.map {|x| x.values[0]}.reduce(:+) unless @tot_each ==nil
  end

  def make_vector
    if @tot_each == nil then return end
    @vector=@tot_each.map {|x| x.values[0]}.to_scale
  end

  def general_day_points_mean
    @mean_tot_points_generalist=@vector.mean  if @vector.class ==Statsample::Vector
  end

  def general_day_points_sd
    @sd_tot_points_generalist=@vector.sd if @vector.class ==Statsample::Vector
  end
end


### This is build around teh counting of activities events matching certain criteria
class SpecialtyReport
  class << self
    attr_accessor :r
  end

  def self.all_gi n=0
    @r=(Activity.where :date=>get_business_utc(n), :specialty=>"Gi-only",:name=>{:$in=>DATA["gi_activities"]}).all
    self
  end

  def self.all_heme n=0
    @r= (Activity.where :date=>get_business_utc(n),:name=>{:$in=>DATA["heme_activities"]}).all
    self
  end


  def self.all_derm n=0
    @r=(Activity.where :date=>get_business_utc(n), :specialty=>"Dermpath-only", :name=>{:$in=>DATA["derm_activities"]}).all
    self
  end

  def self.all_general n=0
    @r=(Activity.where :date=>get_business_utc(n),:specialty_only =>false, :name=>{:$in=>DATA["general_activities"]}).all
    self
  end

  def self.all_cytology n=0
    @r=(Activity.where :date=>get_business_utc(n), :name=>{:$in=>DATA["cytology_activities"]}).all
    self
  end

  def self.tot_points
    @r.map {|x| x.tot_points}.reduce(:+)
  end
end

def report_build n=0
  #load specialty reports
  dr=DayReport.new
  dr.all_gi=SpecialtyReport.all_gi(n).tot_points
  dr.all_heme=SpecialtyReport.all_heme(n).tot_points
  dr.all_derm=SpecialtyReport.all_derm(n).tot_points
  dr.all_general=SpecialtyReport.all_general(n).tot_points
  dr.all_cytology=SpecialtyReport.all_cytology(n).tot_points
  dr.date=get_business_utc n
  #load setup reports
  s=SetupReport.new n
  dr.slides_blocks_ratio=s.get_general_slides_blocks_ratio
  dr.left_over_previous_day_slides=s.get_left_over_previous_day_slides
  dr.pathologist_working=s.get_pathologist_working


  #load distribution reports
  d=DistReport.new n
  #xxx
  dr.general_day_points_hash= d.tot_each.to_json
  dr.general_day_points_tot= d.general_day_points_tot
  dr.general_day_points_mean= d.general_day_points_mean
  dr.general_day_points_sd= d.general_day_points_sd

  dr.save
end

def report_json
  r={}
  exclude=["date", "_id", "reporter_mongo_id", "general_day_points_hash"]
  #precreate empty arrays
  DayReport.keys.keys.each do |k|
    r[k]=[] unless exclude.include? k
  end
  #loads arrays
  DayReport.all(:order => :date.asc).each do |dr|
    dr.keys.keys.each do |k|
      r[k]<<dr[k] unless exclude.include? k
    end
  end
  #change structure to make it more amanable for handlebars
  results_array=[]
  r.each do |k,v|
    v.delete(nil)
    results_array<<{:name=> k, :r=>v}
  end

  {:plot=>results_array}
end

$scheduler = Rufus::Scheduler.start_new



$scheduler.cron '0 23 * * 1-5' do
  # every day of the week at 11pm
  puts 'activate reportimg system'
  report_build
  puts "report completed"
end

def mongodump
  command= "mongodump -d path-tracker -o /Users/carlobifulco/mongodump"
  puts command
  system command
end

def mongoexport
  command="mongoexport --collection activities --out /Users/carlobifulco/mongodump/activities.json"
  puts command
  system command
end

# every day of the week at 10pm
$scheduler.cron '0 22 * * 1-5' do
  puts "mongo-dumping"
  mongodump
end

# every day of the week at 10pm and 5 minutes
$scheduler.cron '5 22 * * 1-5' do
  puts "mongo-exporting"
  mongoexport
end

$scheduler.every '10m' do
   puts "Hola; 10 minutes passed"
 end



def test_graph
  switch_to_testing
  DayReport.delete_all
  clean
  (-50..0).each do |i|
    simulate i
    report_build i
  end
end

puts "\n---------------------------------------"
puts "**************#{$scheduler.cron_jobs}**************"
puts "\n----------------------------------------"
#If not in event machine
#$scheduler.join

