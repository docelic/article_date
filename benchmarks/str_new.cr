require "benchmark"

a = "testtestte"
b = nil

Benchmark.ips(warmup:1) do |x|
  x.report("String.new(.chars.join)") { b = "testtestte".chars.join }
  x.report("String.new(string[0..9])") { b = a[0..9] }
end
