my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory

require "web_data"
require "configuration"

# Main interface to the web application
# Setter methods
module TodaySet
  def set_path_off ini
    p=self.get_path_by_ini ini
    p.working=false
    p.save
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

# Main interface to the web application
# Getter methods
module TodayGet
  def get_path_all
    t=Tdc.today @n
    t.pathologist
  end
   #magic souce formula....
  def get_points_slide_tot
     t=Tdc.today @n
     #conversion blocks slides
     total_slide_points= SLIDES_CONVERSION_FACTOR * (t.blocks_west+t.blocks_east+t.blocks_hr)
     total_slide_points.to_int
  end
  #these are theroetical based on the number of blocks/slides to be distributed
  def get_points_tot
    t=Tdc.today @n
    t.tot_points=(t.get_predicted_points_slide_tot + Activity.get_general_non_slide_points(@n))
    #puts t.tot_points
    t.save
    return t.tot_points
  end

  #this includes pnly actual slides distributed
  def get_real_points_distributed
    self.get_general_slides_distributed+Activity.get_general_non_slide_points(@n)
  end

  def get_path_working
    t=Tdc.today @n
    t.pathologist.select {|x| x.working==true}
  end

  def get_number_path_working
    self.get_path_working().count
  end

  def get_path_specialty
    t=Tdc.today @n
    # only if working....
    t.pathologist.select {|x| x.specialty_only==true} &  t.pathologist.select {|x| x.working==true}
  end

  def get_path_absent
    t=Tdc.today @n
    t.pathologist.select {|x| x.working==false}.map {|x| x.ini}
  end

  def get_general_slides_distributed
    Activity.get_general_slides_distributed @n
  end

  def get_slides_to_be_distributed
    t=Tdc.today @n
    (t.get_predicted_points_slide_tot/SLIDES_CONVERSION_FACTOR)-get_general_slides_distributed
  end

  def get_path_by_ini ini
    t=Tdc.today @n
    p=t.pathologist.select {|x| x.ini==ini}
    p[0] if p.count>0
  end
end


####Points calculator
class PointsCalculator
  attr_accessor :predicted_general_slides_tot,:general_slides_distributed,:predicted_general_slides_pending
  attr_accessor :total_general_predicted_points,:general_activity_points, :general_non_slide_points
  attr_accessor :slides_conversion_factor
  attr_accessor :general_tot, :non_specialist_count
  def initialize n=0, slides_conversion_factor=SLIDES_CONVERSION_FACTOR
    @slides_conversion_factor=slides_conversion_factor
    #puts "#{slides_conversion_factor}  --here"
    @t=Tdc.today n
    #1st number upon which all the rest is build
    @general_tot = (@t.blocks_tot-@t.total_GI-@t.total_SO-@t.total_ESD)+@t.total_cytology+@t.left_over_previous_day_slides
    #2nd find slidesdelivered
    @general_slides_distributed=Activity.get_general_slides_distributed(@t.n)
    # find theoretical tot slides based on blocks an conversion factor
    @predicted_general_slides_tot=get_predicted_general_slides_tot(@slides_conversion_factor)
    #puts  @slides_conversion_factor, "HeRE WE ARE"
    #correct if factor is wrong  --ie more slides are out then theroetically possible
    ratio_adjustment
    @predicted_general_slides_pending=@predicted_general_slides_tot- @general_slides_distributed
    @general_activity_points=Activity.get_general_non_slide_points(@t.n)
    @total_general_predicted_points=@predicted_general_slides_tot+@general_activity_points
    @non_specialist_count=Pathologist.get_number_generalist(@t.n)
  end

  #again based on generalist blocks and activities only
  def predicted_slides_per_non_specialist
    if non_specialist_count !=0
      predicted_general_slides_pending/non_specialist_count
    else
      return 1
    end
  end

  #### heart of the system
  def hard_ratio
    (general_slides_distributed/general_tot.to_f) unless (general_tot.to_f ==0)
  end
  # move away from baseline if numbers greater then initial trashold
  def ratio_adjustment
    if general_slides_distributed > predicted_general_slides_tot and (predicted_general_slides_tot != 0)
      @slides_conversion_factor=hard_ratio
      puts "number of predicted slides was #{predicted_general_slides_tot} but we have distributed #{general_slides_distributed}; new cf is: #{slides_conversion_factor}"
      @predicted_general_slides_tot=get_predicted_general_slides_tot(slides_conversion_factor)
      puts "Adjusted ratio to #{slides_conversion_factor}; new numebr of predicted slides is #{predicted_general_slides_tot}"
    end
  end

  #general blocks only * conversion factor +cyto and left overs
  def get_predicted_general_slides_tot slides_conversion_factor
    #puts "general tot =#{@general_tot}; #{slides_conversion_factor}"
    (general_tot*slides_conversion_factor).to_i
  end

  def predicted_points_per_non_specialist
    if non_specialist_count !=0
      total_general_predicted_points/non_specialist_count
    else
      return 1
    end
  end
end


#### Main interface to sinatra calls
class Today
  include TodaySet
  include TodayGet

  attr_accessor :tdc, :n, :all_activities_points, :time, :date

  def initialize n=0
    @all_activities_points= DATA["regular_activities"].merge DATA["cardinal_activities"]
    # @ n is the number of days after today; needs to tak into accound weekends/holidays

    #actuallu used only for debugging
    @tdc=Tdc.today n
    @n=@tdc.n
    @time=@tdc.date
    @date=@time.to_date
  end

  def get_tot_blocks
    t=Tdc.today @n
    t.blocks_west+t.blocks_east+t.blocks_hr
  end

  def n_histology_slides_distributed n=0
    histology_slides=["Slides-large-cases", "Slides-small-cases"]
    r=Activity.find_all_by_name_and_date(histology_slides, get_business_utc(n))
    ((r.map {|x| x.n}.reduce(:+)) or 0)
  end



  # all paths for the day
  # XXX
  def get_setup
    #Tdcs need to be genrated fresh for each call
    t=Tdc.today @n
    pc=PointsCalculator.new @n
    slides_distributed=pc.general_slides_distributed;
    activity_points=pc.total_general_predicted_points-pc.predicted_general_slides_tot
    if slides_distributed then slides_remaining=pc.predicted_general_slides_tot - slides_distributed else slides_remaining=pc.predicted_general_slides_tot/SLIDES_CONVERSION_FACTOR end
    pathologist_working=self.get_path_working.map { |x| x.ini }
    path_count= self.get_path_working.count
    setup={blocks_tot: t.blocks_tot,
          blocks_general: t.blocks_tot - (t.total_GI + t.total_SO + t.total_ESD),
          slides_conversion_factor: pc.slides_conversion_factor,
          total_GI: t.total_GI,
          total_SO: t.total_SO,
          total_ESD: t.total_ESD,
          left_over_previous_day_slides: t.left_over_previous_day_slides,
          total_cytology: t.total_cytology,
          tot_points: pc.total_general_predicted_points,
          slide_points: pc.predicted_general_slides_tot,
          activity_points: pc.general_activity_points,
          pathologist_all: self.get_path_all.map { |x| x.ini  },
          pathologist_working: (pathologist_working).sort,
          pathologist_absent: (self.get_path_absent).sort,
          path_count: path_count,
          date: t.date.to_s,
          slides_distributed: pc.general_slides_distributed,
          slides_remaining: slides_remaining,
          generalist_count:Pathologist.get_number_generalist,
          n_histology_slides_distributed: self.n_histology_slides_distributed
          }
    setup[:points_per_pathologist]= pc.predicted_points_per_non_specialist
    return setup
  end


  # equation for asserting total points per head
  #only for generalists
  def points_per_path
    tot_points=self.get_points_tot
    path_count= self.get_path_working.count-self.get_path_specialty.count
    if path_count !=0
      tot_points/path_count
    else
      return 1
    end
  end

  def set_path_tomorrow params
    t=Tdc.today @n
    self.set_present(params['path_present']) unless (not (params.has_key? 'path_present'))
    self.set_absent(params['path_absent']) unless (not (params.has_key? 'path_absent'))
    return true
  end


  def set_setup params
    t=Tdc.today @n
    #puts params
    #puts " params is #{params}; and has key #{params.has_key? 'blocks_east'}"
    t.blocks_tot=params['total_blocks'] #unless (not (params.has_key? 'blocks_east'))
    t.total_GI=params['total_GI'] #unless (not (params.has_key? 'blocks_west'))
    t.total_SO=params['total_SO']
    t.total_ESD=params['total_ESD']
    t.total_cytology=params['total_cytology']
    t.left_over_previous_day_slides=params["left_over_previous_day_slides"]
    t.save
    puts t.blocks_tot
    self.set_present(params['path_present']) unless (not (params.has_key? 'path_present'))
    self.set_absent(params['path_absent']) unless (not (params.has_key? 'path_absent'))
    return true
  end

  def get_entry
    t=Tdc.today @n
    pc=PointsCalculator.new
    puts "#{t.date } with an #{t.n}; Today n is #{@n}"
    entry={
      pathologist_working: Pathologist.get_path_working(t.n).map{ |x| x.ini}.sort(),
      paths_acts_points: Pathologist.all_activities_points(t.n),
      paths_tot_points: Pathologist.path_all_points(t.n),
      slides_distributed: Activity.get_general_slides_distributed(t.n),
      slides_remaining: pc.predicted_general_slides_pending,
      date: t.date.to_date,
       # avoid 0 division crashes
      slides_remaining_per_pathologist: pc.predicted_slides_per_non_specialist
     }
  end

  # as get entry but restricted to generalists
  def get_live
    t=Tdc.today @n
    pc=PointsCalculator.new
    puts "#{t.date } with an #{t.n}; Today n is #{@n}"
    entry={
      #this is different  --no specialists...
      pathologist_working: Pathologist.get_generalist(t.n).map{ |x| x.ini}.sort(),
      paths_acts_points: Pathologist.all_activities_points_generalist(t.n),
      paths_tot_points: Pathologist.path_all_points(t.n, pathologist=Pathologist.get_generalist()),
      slides_distributed: Activity.get_general_slides_distributed(t.n),
      slides_remaining: pc.predicted_general_slides_pending,
      date: t.date.to_date,
       # avoid 0 division crashes
      slides_remaining_per_pathologist: pc.predicted_slides_per_non_specialist
     }
  end


  def get_path_activities_points
    return Pathologist.all_activities_points @n
  end

  #activities entry point for regular
  def set_regular path_ini, activity_name, n
    #XXX needto find out
    p=self.get_path_by_ini path_ini
    a=self.get_activity path_ini, activity_name
    a.n=n
    #a.specialty_only=p.specialty_only
    p.activities<<a
    a.save
    p.save
    puts "just updated for you #{path_ini}'s #{a.name} to a number of #{a.n} and tot_points of #{a.tot_points} "
  end

  #activities entry point for cardinal
  def set_cardinal path_ini, on_array
    t=Tdc.today @n
    no_work_activities=DATA["no-points"].keys
    p=self.get_path_by_ini path_ini
    off_array=DATA["cardinal_activities"].keys.select{|x| not (on_array.member? x)}
    #puts "on: #{on_array}; not on #{off_array}"
    on_array.each do |activity_name|
      a=self.get_activity path_ini, activity_name
      a.n=1
      p.activities<<a
      a.save
      # if activity is one of the no-work-acts them set pathologist as specialty only
      #puts "Specialty? :#{DATA["no-points"].keys.include? activity_name}"
      if DATA["distribution-specialty"].keys.include? activity_name
        p.specialty_only=true
        # important call
        p.update_specialty_status activity_name
      end
    end
    #deke off activities
    off_array.each do |activity_name|
      a=Activity.get_ini_name(t.n,path_ini,activity_name)
      a.destroy if a
    end
    p.save
  end

  def get_activity path_ini, activity_name
    r=Activity.where(:ini=>path_ini,:date=>@time,:name=>activity_name)
    if r.count==1
      puts "existing activity"
      return r.all[0]
    # p=self.get_path_by_ini path_ini
    # path_existing_activities=p.activities.map{|x| x.name}
    # if path_existing_activities.member? activity_name
    #    a=Activity.get_ini_name(@n, path_ini,activity_name)
    else
      puts "new activity"
      a=Activity.new
      a.date=@time
      a.name=activity_name
      a.ini=path_ini
      if @all_activities_points.has_key? activity_name then a.points=@all_activities_points[activity_name] else return false end
    end
    return a
  end

  def save_activity path_ini, activity_name, n=false
  end
end
