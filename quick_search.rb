#require 'rserve/simpler'
#$r = Rserve::Simpler.new
require "csv"


# paps=Activity.where(:name=>"Paps").all
# $s={}
# paps.each do |p|
#   if $s.has_key? p.ini
#     $s[p.ini]=($s[p.ini]+p.n)
#   else
#     $s[p.ini]=p.n 
#   end
#   puts p.ini, p.n
# end
# puts $s

# $d={}
# paps.each do |p|
#   if $d.has_key? p.date.to_s
#     $d[p.date.to_s]=($d[p.date.to_s]+p.n)
#   else
#     $d[p.date.to_s]=p.n
#   end
#   puts p.date.to_s, p.n
# end


def rify data_list
  puts "c(#{data_list})".gsub("[","").gsub("]","")
end

# class Dog
#    attr_accessor :k
#    def initialize
#     @k=33333
#    end
# end



$d=CSV.generate do |csv|
  keys=Activity.keys.keys
  csv << keys
  Activity.all.each do |a|
    temp=[]
    keys.each do |k|
      temp << a.send(k)
    end
    csv<<temp
  end
end