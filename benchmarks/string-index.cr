require "benchmark"

a = ("testtest" * 2).chars.join
b = nil

Benchmark.ips(warmup:1) do |x|
  x.report("str#index") { b = a[8] }
end
