require "benchmark"

a = "aaaa".chars.join
b= [a]

c = nil

Benchmark.ips(warmup:1) do |x|
  x.report("str.x") { c = a.bytesize}
  x.report("b.each {|x| x.x}") { b.each do |x| c = x.bytesize end }
end
