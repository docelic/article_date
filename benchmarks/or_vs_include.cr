require "benchmark"

list = ['a','b','c']
r= false

Benchmark.ips(warmup:1) do |x|
  x.report("list.includes? x")     { r=(list.includes? 'c' }
  x.report("x==a or x==b or x==c") { r=(('c' == 'a') || ('c' == 'b') || ('c' == 'c')) }
end
