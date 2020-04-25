require "benchmark"

a = "testtest" * 1000
b = nil

Benchmark.ips(warmup:1) do |x|
  x.report("String#bytesize") { b = a.bytesize } # (optimized away)
  x.report("C strlen") { b = LibC.strlen a }
end
