require "benchmark"

a = "testtest" * 1000

Benchmark.ips(warmup:1) do |x|
  x.report("String#bytesize") { a.bytesize }
  x.report("C strlen") { LibC.strlen a }
end
