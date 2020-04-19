require "benchmark"

a = "aaaa".chars.join

Benchmark.ips(warmup:1) do |x|
  x.report("downcase") { a.downcase}
  x.report("upcase") { a.upcase}
end
