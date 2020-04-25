require "benchmark"

lib LibC
  fun strstr(::LibC::Char*, ::LibC::Char*) : ::LibC::Char*
  fun strrchr(::LibC::Char*, ::LibC::Char) : ::LibC::Char*
  fun memrchr(Void*, ::LibC::Char, ::LibC::SizeT) : Void*

  #fun strrstr(::LibC::Char*, ::LibC::Char*) : ::LibC::Char*
  #fun index(::LibC::Char*, ::LibC::Char) : ::LibC::Char*
  #fun rindex(::LibC::Char*, ::LibC::Char) : ::LibC::Char*
end

#       600                600           600
a = "pre" * 200 + '<' + "mid" * 200 + '>' + "pos" * 200

z = nil

p LibC.strstr(a.to_unsafe, "<") - a.to_unsafe
p LibC.strrchr(a.to_unsafe, 60) - a.to_unsafe
p LibC.memrchr(a.to_unsafe, 60, 700).as(::LibC::Char*) - a.to_unsafe

Benchmark.ips(warmup:1) do |x|
  x.report("strstr (test)") { c = a.to_unsafe[700]; a.to_unsafe[700] = 0; z = LibC.strstr(a.to_unsafe, "<") - a.to_unsafe; a.to_unsafe[700] = c;}
  x.report("strrchr (good)") {c = a.to_unsafe[700]; a.to_unsafe[700] = 0; z = LibC.strrchr(a.to_unsafe, 60) - a.to_unsafe ; a.to_unsafe[700] = c;}
  x.report("memrchr (good)") { z = LibC.memrchr(a.to_unsafe, 60, 700).as(::LibC::Char*) - a.to_unsafe }
end

Benchmark.ips(warmup:1) do |x|
  x.report("strstr (test)") { z = LibC.strstr(a.to_unsafe, ">") - a.to_unsafe}
  x.report("strchr (good)") {z = LibC.strrchr(a.to_unsafe + 700, 62) - a.to_unsafe}
  x.report("memchr (good)") { z = LibC.memchr(a.to_unsafe + 700, 62, a.bytesize).as(::LibC::Char*) - a.to_unsafe }
end
