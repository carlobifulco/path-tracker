my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


#require "statsample"
require "web_data"


class  DistributionBoxPlot <DataRedis

end

class GiVolumes <DataRedis
  def initialize


  end
end
