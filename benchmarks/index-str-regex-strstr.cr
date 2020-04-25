require "benchmark"
lib LibC
  fun strstr(Char*, Char*) : Char*
  fun strchr(Char*, Char) : Char*
  fun strcasestr(Char*, Char*) : Char*
end

n = "<" # 60
nr = Regex.new n

p = "needl" # Intentionally partial without 'e'
haystacks = {
  p25:  p * (25) + n,
  p50:  p * (50) + n,
  p100:  p * (100) + n,
  p250:  p * (250) + n,
  p500:  p * (500) + n,
  p750:  p * (750) + n,
  p1k:   p * (10^3) + n,
  p25k:   p * (25 * 10^3) + n,
  p50k:   p * (50 * 10^3) + n,
  p75k:   p * (75 * 10^3) + n,
  #p100k: p * (10^5) + n,
  #p1M:   p * (10^6) + n,
  #p3M:   p * (3 * 10^6) + n,
  #p10M:  p * (10^7) + n,
}

# Quick verification that all three methods give valid result
h = haystacks.values.first
unless h.index(n) == h.index(nr) == LibC.strstr(h, n) - h.to_unsafe ==  LibC.strchr(h, 60) - h.to_unsafe
  raise Exception.new "Check source code!"
end

z = nil

Benchmark.ips(warmup: 1, calculation: 2) do |x|
  haystacks.each do |name, haystack|
    x.report("#{name}.index string")  { z = haystack.index n }
    x.report("#{name}.index regex")   { z = haystack.index nr }
    x.report("#{name}.strstr string") { z = LibC.strstr(h, n) - haystack.to_unsafe }
    x.report("#{name}.strchr char") { z = LibC.strchr(h, 60) - haystack.to_unsafe }
    x.report("#{name}.strcasestr string") { z = LibC.strcasestr(h, n) - haystack.to_unsafe }
  end
end
