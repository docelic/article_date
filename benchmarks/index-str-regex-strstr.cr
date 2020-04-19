require "benchmark"
lib LibC
  fun strstr(Char*, Char*) : Char*
  fun strcasestr(Char*, Char*) : Char*
end

n = "needle"
nr = Regex.new n

p = "needl" # Intentionally partial without 'e'
haystacks = {
  p100:  p * (100) + n,
  p1k:   p * (10^3) + n,
  p100k: p * (10^5) + n,
  p1M:   p * (10^6) + n,
  p3M:   p * (3 * 10^6) + n,
  p10M:  p * (10^7) + n,
}

# Quick verification that all three methods give valid result
h = haystacks.values.first
unless h.index(n) == h.index(nr) == LibC.strstr(h, n) - h.to_unsafe
  raise Exception.new "Check source code!"
end

Benchmark.ips(warmup: 1, calculation: 2) do |x|
  haystacks.each do |name, haystack|
    x.report("#{name}.index string")  { haystack.index n }
    x.report("#{name}.index regex")   { haystack.index nr }
    x.report("#{name}.strstr string") { LibC.strstr(h, n) - haystack.to_unsafe }
    x.report("#{name}.strcasestr string") { LibC.strcasestr(h, n) - haystack.to_unsafe }
  end
end
