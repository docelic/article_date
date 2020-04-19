require "benchmark"

a = ("testtest" * 2).chars.join

Benchmark.ips(warmup:1) do |x|
  x.report("str#index") { a[8] }
end
