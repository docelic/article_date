require "benchmark"

a = "aaaa".chars.join
b= [a]

Benchmark.ips(warmup:1) do |x|
  x.report("str.x") { a.bytesize}
  x.report("b.each {|x| x.x}") { b.each do |x| x.bytesize end }
  x.report("b.each &.x") { b.each &.bytesize }
end
