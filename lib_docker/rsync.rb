require_relative "config"
APP_NAME=File.basename File.absolute_path "."
PRODUCTION_SERVER_IP=CONFIG["PRODUCTION_SERVER_IP"]

module Rsync


  def self.rsync_install ip=PRODUCTION_SERVER_IP
    command="rsync -avzd   #{File.absolute_path "."} p337922@#{ip}:/home/p337922"
    puts command.red
    puts `rsync -avzd   #{File.absolute_path "."} p337922@#{ip}:/home/p337922`
  end

  ### No changes to the results directory   --annotatians intermediate files etc...
  # def self.rsync_update ip=PRODUCTION_SERVER_IP
  #   puts `rsync -avzd  --exclude  next_gen_results ~/Dropbox/code/next_gen carlobifulco@#{ip}:~/Dropbox/code`
  # end
  #XXX
  def self.rsync_pull_mongo ip=PRODUCTION_SERVER_IP
    mongo_dir=File.relative_path "./", (File.absolute_path MONGO_DUMP_PATH)
    puts `rsync -avzd carlobifulco@#{ip}:~/Dropbox/code/next_gen/#{mongo_dir}  #{MONGO_DUMP_PATH}   `

  end


end



if __FILE__ == $0
  include Rsync
end
