require "benchmark"

lib LibC
  fun strstr(::LibC::Char*, ::LibC::Char*) : ::LibC::Char*
end

a = "testtest" * 1_000_000
a += "c"
a += a
ptr = LibC.strstr a, "c"
#pos = 10

Benchmark.ips(warmup:1) do |x|
  x.report("Pointer[10]") { ptr[10]; ptr[10]; ptr[10]; }
  x.report("pos + Pointer[pos]") { pos = 10; ptr[pos]; ptr[pos]; ptr[pos]; }
end
