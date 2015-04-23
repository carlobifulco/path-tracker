libs=["lib_docker"]
libs.each  {|lib| $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)}
libs.each do |lib|
  Dir.glob("./#{lib}/*.rb").each {|file_path| load file_path; puts file_path}
end
