require "benchmark"

a = "testtestte"

Benchmark.ips(warmup:1) do |x|
  x.report("String.new(.chars.join)") { "testtestte".chars.join }
  x.report("String.new(string[0..9])") { a[0..9] }
end
