require "benchmark"

lib LibC
  fun strstr(::LibC::Char*, ::LibC::Char*) : ::LibC::Char*
end

a = "testtest" * 1_000_000
a += "c"
a += a
ptr = LibC.strstr a, "c"
#pos = 10

w, y, z = nil, nil, nil

Benchmark.ips(warmup:1) do |x|
  x.report("Pointer[10]") { w=ptr[10]; y=ptr[10]; z=ptr[10]; }
  x.report("pos + Pointer[pos]") { pos = 10; w=ptr[pos]; y=ptr[pos]; z=ptr[pos]; }
end
