require "benchmark"

list = ['a','b','c']

Benchmark.ips(warmup:1) do |x|
  x.report("list.includes? x")     { list.includes? 'c' }
  x.report("x==a or x==b or x==c") { ('c' == 'a') || ('c' == 'b') || ('c' == 'c') }
end
