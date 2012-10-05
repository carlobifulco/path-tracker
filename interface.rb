require "web_data"

# Main interface to the web application
# Setter methods
module TodaySet
  def set_path_off ini
    p=self.get_path_by_ini ini
    p.working=false
    p.save
  end

  def set_blocks_west n
    t=Tdc.today @n
    t.blocks_west=n
    t.save
    puts "blocks west #{t.blocks_west}"
  end

  def set_blocks_east n
    t=Tdc.today @n
    t.blocks_east=n
    t.save
    puts "blocks eats #{t.blocks_east}"
  end

  def set_blocks_hr n
    t=Tdc.today @n
    t.blocks_hr=n
    t.save
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


  # all paths for the day
  def get_setup
    #Tdcs need to be genrated fresh for each call
    t=Tdc.today @n
    tot_points=t.get_predicted_points_all
    blocks_tot=t.blocks_west+t.blocks_east+t.blocks_hr; slide_points=(blocks_tot*SLIDES_CONVERSION_FACTOR).to_i
    slides_distributed=Activity.get_general_slides_distributed(t.n); ; activity_points=tot_points-slide_points
    if slides_distributed then slides_remaining=slide_points - slides_distributed else slides_remaining=slide_points/SLIDES_CONVERSION_FACTOR end
    pathologist_working=self.get_path_working.map { |x| x.ini }
    path_count= self.get_path_working.count
    setup={blocks_west: t.blocks_west,
          blocks_east: t.blocks_east,
          blocks_hr: t.blocks_hr,
          blocks_tot: blocks_tot,
          tot_points: tot_points,
          slide_points: slide_points,
          activity_points: activity_points,
          pathologist_all: self.get_path_all.map { |x| x.ini  },
          pathologist_working: (pathologist_working).sort,
          pathologist_absent: (self.get_path_absent).sort,
          path_count: path_count,
          date: t.date.to_s,
          slides_distributed: slides_distributed,
          slides_remaining: slides_remaining,
          generalist_count:Pathologist.get_number_generalist
          }
    setup[:points_per_pathologist]= t.get_predicted_points_per_non_specialist
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


  def set_setup params
    t=Tdc.today @n
    #puts params
    #puts " params is #{params}; and has key #{params.has_key? 'blocks_east'}"
    self.set_blocks_east params['blocks_east'] #unless (not (params.has_key? 'blocks_east'))
    self.set_blocks_west params['blocks_west'] #unless (not (params.has_key? 'blocks_west'))
    self.set_blocks_hr params['blocks_hr']
    #puts "where are you #{params['blocks_hr']}"
    self.set_present(params['path_present']) unless (not (params.has_key? 'path_present'))
    self.set_absent(params['path_absent']) unless (not (params.has_key? 'path_absent'))
    return true
  end

  def get_entry
    t=Tdc.today @n
    puts "#{t.date } with an #{t.n}; Today n is #{@n}"
    slides_distributed=Activity.get_general_slides_distributed(t.n)
    slides_remaining=t.expected_generalist_distribution_slides- slides_distributed 
    entry={
      pathologist_working: Pathologist.get_path_working(t.n).map{ |x| x.ini}.sort(),
      paths_acts_points: Pathologist.all_activities_points(t.n),
      paths_tot_points: Pathologist.path_all_points(t.n),
      slides_distributed: slides_distributed,
      slides_remaining: slides_remaining,
       # avoid 0 division crashes
      slides_remaining_per_pathologist: slides_remaining/(Pathologist.get_number_generalist(t.n) or 1)
     }
  end

  # as get entry but restricted to generalists
  def get_live
    t=Tdc.today @n
    slides_distributed=Activity.get_general_slides_distributed(t.n)
    slides_remaining=t.expected_generalist_distribution_slides- slides_distributed 
    entry={
      pathologist_working: Pathologist.get_generalist(t.n).map{ |x| x.ini}.sort(),
      paths_acts_points: Pathologist.all_activities_points(t.n),
      paths_tot_points: Pathologist.path_all_points_generalist(t.n),
      slides_distributed: slides_distributed,
      slides_remaining: slides_remaining,
      # avoid 0 division crashes
      slides_remaining_per_pathologist: slides_remaining/(Pathologist.get_number_generalist(t.n) or 1)
    }
  end


  def get_path_activities_points
    return Pathologist.all_activities_points @n
  end

  #activities entry point for regular
  def set_regular path_ini, activity_name, n
    p=self.get_path_by_ini path_ini
    a=self.get_activity path_ini, activity_name
    a.n=n
    p.activities<<a
    a.save
    p.save
    pp "just updated for you #{path_ini}'s #{a.name} to a number of #{a.n} and tot_points of #{a.tot_points} "
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
      if DATA["no-points"].keys.include? activity_name
        p.specialty_only=true
      end
    end
    off_array.each do |activity_name|
      a=Activity.get_ini_name(t.n,path_ini,activity_name)
      a.delete if a
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
