require "benchmark"
require "uri"

a=1
b=1000

Benchmark.ips(warmup:1) do |x|
  x.report("range") { a..b  }
  x.report("tuple") { {a,b}  }
end
