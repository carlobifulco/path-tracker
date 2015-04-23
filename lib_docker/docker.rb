require "colored"
require_relative "config.rb"
require_relative "util"


#MONGO_DATA_ROOT="/Users/carlobifulco/data/db/mongo_dbs"

#
# spawn "docker run -v /data/db --name  #{APP_NAME}-data busybox true"


### closes and reboots all supporting containers



### full code changes pushed into docker

module DockerManager
  APP_NAME=File.basename File.absolute_path "."
  DATABASE_CONTAINER_NAME="database"
  VOLUME_CONTAINER_NAME="volume"
  MONGO_DATA_ROOT=CONFIG["MONGO_DATA_ROOT"]
  SINATRA_PORT=CONFIG["SINATRA_PORT"]

  module_function
  def app_container_build_restart_full_development
    git_tar
    app_container_restart_full(docker_path="./lib_docker/docker_app/", environment="development")
  end



  def app_container_connect
    command= "docker exec -it #{APP_NAME}-container bash"
    puts command.red
    system "docker exec -it #{APP_NAME}-container bash"
  end
  #


  def app_container_restart_full_production
    app_container_restart_full(docker_path="./lib_docker/docker_app/",environment="production")
  end


  def app_container_restart_full_development
    app_container_restart_full(docker_path="./lib_docker/docker_app/", environment="development")
  end

  def app_container_restart_full docker_path="../lib_docker/docker_app/", environment="development"
    ## docker pull carlobifulco/sendout-monitor
    puts "START APP".yellow_on_green
    volume_container_restart
    database_container_restart
    execute_command "docker build  --tag #{APP_NAME}-image #{docker_path}"
    execute_command "docker stop #{APP_NAME}-container"
    execute_command "docker rm -v #{APP_NAME}-container"
    execute_command "docker run -d  -p #{SINATRA_PORT}:#{SINATRA_PORT}  --volumes-from  #{APP_NAME}-#{VOLUME_CONTAINER_NAME}\
                        --name #{APP_NAME}-container\
                        --link #{APP_NAME}-#{DATABASE_CONTAINER_NAME}:db\
                        #{APP_NAME}-image \
                        /usr/local/bin/ruby /root/#{APP_NAME}/server.rb \
                            -p #{SINATRA_PORT} -e #{environment}"
    Thread.new do
      sleep 3
      execute_command "docker top #{APP_NAME}-container"
      execute_command "open http://`boot2docker ip`:#{SINATRA_PORT}" if Util.testing?
    end
    puts "DONE WITH APP".yellow_on_green
  end






  def app_container_restart_light
    execute_command "docker stop #{APP_NAME}-container"
    execute_command "docker rm -v #{APP_NAME}-container"
    execute_command "docker run -d  -p #{SINATRA_PORT}:#{SINATRA_PORT}  --volumes-from  #{APP_NAME}-#{VOLUME_CONTAINER_NAME}\
                                    --name #{APP_NAME}-container\
                                    --link #{APP_NAME}-#{DATABASE_CONTAINER_NAME}:db\
                                    #{APP_NAME}-image \
                                    /usr/local/bin/ruby /root/#{APP_NAME}/server.rb -p #{SINATRA_PORT}"
    Thread.new do
      sleep 3
      execute_command "docker top #{APP_NAME}-container"
      execute_command "open http://`boot2docker ip`:#{SINATRA_PORT}" if Util.testing?
    end

  end

  def app_container_restart_bash
    execute_command "docker stop #{APP_NAME}-container"
    execute_command "docker rm -v #{APP_NAME}-container"
    system "docker run   -it -p #{SINATRA_PORT}:#{SINATRA_PORT}  --volumes-from  #{APP_NAME}-#{VOLUME_CONTAINER_NAME}\
                                    --name #{APP_NAME}-container\
                                    --link #{APP_NAME}-#{DATABASE_CONTAINER_NAME}:db\
                                    #{APP_NAME}-image \
                                    bash"
  end

  def app_container_inspect
    app_container_restart_light
    Thread.new do
      sleep 3
      execute_command "docker top #{APP_NAME}-container"
      execute_command "open http://`boot2docker ip`:#{SINATRA_PORT}"  if Util.testing?
    end
    system "docker exec -it #{APP_NAME}-container pry"

  end





  def database_container_restart docker_path="./lib_docker/docker_database/", container_name=DATABASE_CONTAINER_NAME
    mongo_conf
    puts "START DATABASE".yellow_on_green
    execute_command "docker stop #{APP_NAME}-#{container_name}"
    execute_command "docker rm  #{APP_NAME}-#{container_name}"
    execute_command "docker build  --tag #{APP_NAME}-#{container_name}  #{docker_path}"
    # execute_command "docker run -d --volumes-from  #{APP_NAME}-#{VOLUME_CONTAINER_NAME} \
    #                   --name  #{APP_NAME}-#{container_name} #{APP_NAME}-#{container_name} \
    #                   mongod  --smallfiles "
    execute_command "docker run -d --volumes-from  #{APP_NAME}-#{VOLUME_CONTAINER_NAME} \
                      --name  #{APP_NAME}-#{container_name} #{APP_NAME}-#{container_name} \
                      mongod  --smallfiles --config /etc/mongod.conf"

    Thread.new do
      sleep 3
      execute_command "docker top  #{APP_NAME}-#{container_name}"
    end
    puts "DONE WITH DATABASE".yellow_on_green
  end

  def database_container_failure_inspect docker_path="./lib_docker/docker_database/", container_name=DATABASE_CONTAINER_NAME
    system "docker run -it  #{APP_NAME}-#{container_name} bash"
  end

  def database_container_connect docker_path="./lib_docker/docker_database/", container_name=DATABASE_CONTAINER_NAME
    command= "docker exec -it #{APP_NAME}-#{container_name} bash"
    puts command.red
    system "docker exec -it #{APP_NAME}-#{container_name} bash"
  end

  def database_container_mongoexec docker_path="./lib_docker/docker_database/", container_name=DATABASE_CONTAINER_NAME
    system "docker exec -it  #{APP_NAME}-#{container_name} \
                      mongo "
  end


  ### ./lib_docker/docker_volume/backup.tar" is loaded by teh volumen docker file in /data/db
  def volume_container_restart docker_path="./lib_docker/docker_volume/"
    puts "START VOLUME".yellow_on_green
    persistance_data_directory="#{MONGO_DATA_ROOT}/#{APP_NAME}"
    `mkdir -p #{persistance_data_directory}` unless Dir.exists? persistance_data_directory
    volume_persistence_data_directory_command="bash -c \"mkdir -p #{persistance_data_directory}\""
    volume_container_backup
    execute_command "docker stop #{APP_NAME}-#{VOLUME_CONTAINER_NAME}"
    execute_command "docker rm -v #{APP_NAME}-#{VOLUME_CONTAINER_NAME}"
    `touch "./lib_docker/docker_volume/backup.tar` unless File.exists? "./lib_docker/docker_volume/backup.tar"
    execute_command "docker build  --tag #{APP_NAME}-#{VOLUME_CONTAINER_NAME} #{docker_path}"
    execute_command "docker run -v #{persistance_data_directory}:/data/db  --name  #{APP_NAME}-#{VOLUME_CONTAINER_NAME} #{APP_NAME}-#{VOLUME_CONTAINER_NAME} #{volume_persistence_data_directory_command}"
    puts "DONE WITH VOLUME".yellow_on_green
    #execute_command "docker run -v /data/db  --name  #{APP_NAME}-#{VOLUME_CONTAINER_NAME} #{APP_NAME}-volume"
  end


  ### back up of the app's docker volume /data/db directroy into local docker_volume directory
  # backup is then used by the dockerfile of the volume upon the container restart process
  # this method is applied only in a testing environment
  def volume_container_backup
    execute_command "docker run --volumes-from #{APP_NAME}-#{VOLUME_CONTAINER_NAME} -v `pwd`/lib_docker/docker_volume:/volume_backup ubuntu tar cvf /volume_backup/backup.tar /data/db/#{APP_NAME}" if Util.testing?
  end

  def volume_container_failure_inspect docker_path="./lib_docker/docker_database/", container_name=DATABASE_CONTAINER_NAME
    system "docker start -i   #{APP_NAME}-#{VOLUME_CONTAINER_NAME}"
  end


  ### mounts /data/db on the local file system; not working on os X but only on unix....
  def volume_container_bash docker_path="./lib_docker/docker_database/"
    execute_command "docker stop #{APP_NAME}-#{VOLUME_CONTAINER_NAME}"
    execute_command "docker rm -v #{APP_NAME}-#{VOLUME_CONTAINER_NAME}"
    persistance_data_directory="#{MONGO_DATA_ROOT}/#{APP_NAME}"
    #execute_command "docker run -v /Users/carlobifulco/data/db/#{APP_NAME}:/data/db  --name  #{APP_NAME}-data #{APP_NAME}-volume "
    system "docker run -it -v #{persistance_data_directory}:/data/db  --name  #{APP_NAME}-#{VOLUME_CONTAINER_NAME} #{APP_NAME}-volume bash"
  end

  def volume_container_inspect docker_path="./lib_docker/docker_database/"

    #execute_command "docker run -v /Users/carlobifulco/data/db/#{APP_NAME}:/data/db  --name  #{APP_NAME}-data #{APP_NAME}-volume "
    system "docker inspect  #{APP_NAME}-#{VOLUME_CONTAINER_NAME}"
  end



  def execute_command command_string
    puts "=> .#{command_string}".red
    puts `#{command_string}`.yellow
  end


  # def database_container_connect
  #   command=  "docker exec -it #{APP_NAME}-#{DATABASE_CONTAINER_NAME} bash"
  #   puts command.red
  #   system "docker exec -it #{APP_NAME}-#{DATABASE_CONTAINER_NAME} bash"
  # end

  ### Clean up of environment

  def containers_clean
    execute_command "docker stop `docker ps -a -q`"
    execute_command "docker rm $(docker ps -a -q)"
  end

  def images_clean
    containers_clean
    execute_command "docker rmi `docker images -q`"
  end


  ### Monitor runnning processes
  def containers_top
    `docker ps -a | grep sendout`.split("\n").map{|x| x.split()[0]}.each do |c|

        puts `docker top #{c}`.green

    end
  end


  def git_tar
    puts "GIT & TAR".yellow_on_green
    puts "committing current branch".yellow
    current_branch=`git rev-parse --abbrev-ref HEAD`
    `git commit -am "#{Time.now}: automated deployment - #{`whoami`}"`
    puts "archiving current branch for image creation in docker app".yellow
    `git archive -o ./lib_docker/docker_app/latest.tar -v #{current_branch}`
    `git commit -am "#{Time.now}: automated deployment - #{`whoami`}"`
    begin
      `git push`
    rescue
      "puts failed to reach github..."
    end
    puts "DONE WITH GIT & TAR".yellow_on_green
  end

  def mongo_conf
    x=File.read("./lib_docker/docker_database/mongod.conf")
    x.gsub! /\/data\/db.*/, "/data/db/#{APP_NAME}"
    File.write("./lib_docker/docker_database/mongod.conf", x)
  end

end


if __FILE__ == $0
  include DockerManager
end
