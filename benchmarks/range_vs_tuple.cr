require "benchmark"
require "uri"

a=1
b=1000
c= "test" * 1000
d= nil

Benchmark.ips(warmup:1) do |x|
  x.report("range") { d = c[a..b]  }
  #x.report("tuple") { d = {a,b}  }
end
