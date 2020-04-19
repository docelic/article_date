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


p LibC.strstr(a.to_unsafe, "<") - a.to_unsafe
p LibC.strrchr(a.to_unsafe, 60) - a.to_unsafe
p LibC.memrchr(a.to_unsafe, 60, 700).as(::LibC::Char*) - a.to_unsafe

Benchmark.ips(warmup:1) do |x|
  x.report("strstr (test)") { c = a.to_unsafe[700]; a.to_unsafe[700] = 0; LibC.strstr(a.to_unsafe, "<") - a.to_unsafe; a.to_unsafe[700] = c;}
  x.report("strrchr (good)") {c = a.to_unsafe[700]; a.to_unsafe[700] = 0; LibC.strrchr(a.to_unsafe, 60) - a.to_unsafe ; a.to_unsafe[700] = c;}
  x.report("memchr (good)") { LibC.memrchr(a.to_unsafe, 60, 700).as(::LibC::Char*) - a.to_unsafe }
end
#
#
#  #x.report("memrchr") { LibC.memrchr(a.to_unsafe + 700, 62, 700).as(::LibC::Char*) }
##Benchmark.ips(warmup:1) do |x|
##  #x.report("index") { LibC.index a.to_unsafe + 700, 62 }
##  x.report("rindex") { a.to_unsafe + 700, 62 }
##end
