require "open3"
require_relative "config"


module Util
	def self.hostname
		i,o,e,t= Open3.popen3 "hostname"
		o.read.strip
	end
	def self.testing?
		if CONFIG["TESTING_MACS"].include? self.hostname
      $scanning_directory="Users/carlobifulco/Dropbox/code/definiens_extractor/test"
  		return true
  	else
  		return false
		end
	end
	def self.execute_command command_string
	  puts "=> .#{command_string}".red
	  puts `#{command_string}`.yellow
	end

end
