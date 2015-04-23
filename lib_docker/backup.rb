require 'rufus-scheduler'
require 'mongo_mapper'
require_relative "../web_data"
require_relative "config"
require_relative "util"




$scheduler = Rufus::Scheduler.new

include Mongo



module MongoBackup

  DATABASE_NAME=File.basename File.absolute_path "."
  MONGO_DUMP_PATH=File.absolute_path(CONFIG["MONGO_DUMP_PATH"])
  MONGO_DATA_EXPORTS=File.absolute_path(CONFIG["MONGO_DATA_EXPORTS"]+"/"+DATABASE_NAME)
  MONGO_DUMP_RSYNC=File.absolute_path(CONFIG["MONGO_DATA_ROOT"]+"/"+DATABASE_NAME)




  def self.tar_older_then_7_days? date_string
    puts date_string
    if ((Date.today) - Date.parse(date_string)).to_i > 7
      return true
    else
      return false
    end
  end


  def self.prompt(*args)
      print(*args)
      gets.strip
  end


  def self.clean_db
    if prompt("Are you REALLY sure you want to clean all of #{ MongoMapper.database.name } database??? yes/no: ") =="yes"
      puts " YOU HAVE A CLEAN DATABASE"
    else
      puts "GLAD YOU DECIDED NOT TO WIPE OUT A PRODUCTION SETTING..."
    end
  end

  def self.mongo_tar directory="#{MONGO_DUMP_PATH}/#{DATABASE_NAME}"
    dir_to_be_archived=directory
    command="tar  czfv  #{MONGO_DUMP_PATH}/#{Date.today.to_s}_#{DATABASE_NAME}.tar.gz #{dir_to_be_archived}"
    Util.execute_command command
  end

  def self.mongo_dump
    command="mongodump  --host #{MONGO_HOST}   --port #{MONGO_PORT} --db #{DATABASE_NAME} --out #{MONGO_DUMP_PATH}"
    Util.execute_command command
    mongo_tar
    clean_old_file
    rsync_dump

  end

  def self.rsync_dump host=MONGO_DUMP_PATH, dest=MONGO_DUMP_RSYNC
    FileUtils.mkdir_p dest unless Dir.exists?(dest)
    command="rsync -avz #{ MONGO_DUMP_PATH}/ #{MONGO_DUMP_RSYNC}"
    Util.execute_command command
  end


  ### resets and then imports from mongodump directory
  def self.mongo_restore
    mongo_client = MongoClient.new(MONGO_HOST ,MONGO_PORT)
    mongo_client.drop_database("#{DATABASE_NAME}")
    puts `mongorestore   --host #{MONGO_HOST}   --port #{MONGO_PORT} #{MONGO_DUMP_PATH}/#{DATABASE_NAME} -d #{DATABASE_NAME}`
  end

  ### removes old files  --according to date stamp encoded in file name
  def self.clean_old_file file_ext=".tar.gz", path=MONGO_DUMP_PATH
    (Dir.glob "#{path}/*#{file_ext}").each do |fp|
      tar_date= File.basename(fp).match(/\d*-\d*-\d*/).to_s
      if tar_older_then_7_days?(tar_date)
        puts "#{fp} is more then 7 days old".yellow
        FileUtils.rm_f fp
        puts "removed #{fp}".red
      else
        puts "#{fp.green} stays"
      end
    end
  end


  def self.mongo_export
    FileUtils.mkdir_p MONGO_DATA_EXPORTS unless Dir.exists? MONGO_DATA_EXPORTS
    MongoMapper.database.collection_names.select \
                    {|x| x != "system.indexes"}.each do |collection_name|
      export_file_name= "#{MONGO_DATA_EXPORTS}/#{Date.today.to_s}_#{collection_name}"
      command="mongoexport   --host #{MONGO_HOST}   --port #{MONGO_PORT} \
                        -d #{DATABASE_NAME} --collection #{collection_name} \
                          --out #{export_file_name}.json"
      puts "=>#{command}".red
      system command
      mongo_class=(Object.const_get "#{collection_name.camelize[0...-1]}")
      puts mongo_class.to_s.red
      mongo_class.all.mongo_search_to_csv "#{export_file_name}.csv"
    end
    clean_old_file ".json", MONGO_DATA_EXPORTS
    clean_old_file ".csv", MONGO_DATA_EXPORTS
  end

end




$scheduler.cron '59 23 * * 1-7' do
  MongoBackup.mongo_dump
  MongoBackup.mongo_export
end




puts "\n---------------------------------------"
puts "**************#{$scheduler.jobs}**************"
puts "\n----------------------------------------"


if __FILE__ == $0
  include MongoBackup
end
