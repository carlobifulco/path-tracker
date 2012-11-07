my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory



require "web_data"
require 'rufus/scheduler'



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
  dr=DayReport.new
  dr.all_gi=SpecialtyReport.all_gi(n).tot_points
  dr.all_heme=SpecialtyReport.all_heme(n).tot_points
  dr.all_derm=SpecialtyReport.all_derm(n).tot_points
  dr.all_general=SpecialtyReport.all_general(n).tot_points
  dr.all_cytology=SpecialtyReport.all_cytology(n).tot_points
  dr.date=get_business_utc n
  s=SetupReport.new n
  dr.slides_blocks_ratio=s.get_general_slides_blocks_ratio
  dr.left_over_previous_day_slides=s.get_left_over_previous_day_slides
  dr.pathologist_working=s.get_pathologist_working
  dr.save
end

def report_json 
  r={}
  exclude=["date", "_id", "reporter_mongo_id"]
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
    results_array<<{:name=> k, :r=>v}
  end

  {:plot=>results_array}
end

$scheduler = Rufus::Scheduler.start_new



$scheduler.cron '0 23 * * 1-5' do
  # every day of the week at 11pm
  puts 'activate reportimg system'
  report_build
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


def test_graph
  switch_to_testing  
  DayReport.delete_all
  clean
  (-50..0).each do |i|
    simulate i
    report_build i
  end
end


#If not in event machine
#$scheduler.join
