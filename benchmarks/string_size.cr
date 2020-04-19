

require "benchmark"

a= "test" * 1_000_000

lib LibC
  #fun strlen(Char*) : Int
end

Benchmark.ips(warmup: 1, calculation: 5) do |x|
 x.report("String#size") { a.size }
 x.report("strlen") { LibC.strlen a }
end
Benchmark.ips(warmup: 1, calculation: 5) do |x|
 x.report("create + String#size") { b = "testtest"; b_len = b.size }
 x.report("create + strlen") { b = "testtest"; b_len = LibC.strlen b }
end
