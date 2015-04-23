my_directory=File.dirname(File.expand_path(__FILE__))
$LOAD_PATH << File.join(my_directory,'/lib')
$LOAD_PATH << my_directory


#require "statsample"
require "web_data"
#require 'rserve'
require "redis"
require "redis-namespace"


# Implements some basic methods related to redis
class DataRedis
  attr_accessor :redis_name_spaced
  #redis expiration set at 15 days  24*360*15
  @@expire=129600

  def initialize
    @redis_name_spaced=get_redis_name_spaced
  end

  #Redis namespace
  #
  # Example:
  #
  #r['foo'] = 1000
  #This will perform the equivalent of:
  #redis-cli set ns:foo 1000
  def get_redis_name_spaced
    #checks global testing and if true introduces separate namespacing
    if $redis_testing
      Redis::Namespace.new("testing_"+self.class.to_s , :redis =>$redis)
    else
      Redis::Namespace.new(self.class.to_s, :redis =>$redis)
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
end


class  DistributionBoxPlot <DataRedis

end

class GiVolumes <DataRedis
  def initialize


  end
end