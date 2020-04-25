require "benchmark"
require "uri"

require "../src/app/parser"
require "../src/app/parser/html"
require "../src/app/processor"
require "../src/app/parser/html/basic.cr"

lib LibC
  fun strstr(::LibC::Char*, ::LibC::Char*) : ::LibC::Char*
  fun strrchr(::LibC::Char*, ::LibC::Char) : ::LibC::Char*
end

#       600                600           600                 60
a = "pre" * 200 + %q{<meta name="article:published" content="2020-01-01" and more>} + "pos" * 200

r = nil

p App::Parser::HTML::Basic.find_range(a, {"<meta"}, {"</meta"})
p App::Parser::HTML::Basic.find_enclosing(a, LibC.strstr(a, ":pub") - a.to_unsafe)

Benchmark.ips(warmup:1) do |x|
  x.report("range")     { r = App::Parser::HTML::Basic.find_range(a, {"<meta"}, {"</meta"}, 0, false) }
  x.report("enclosing") { r = App::Parser::HTML::Basic.find_enclosing(a, LibC.strstr(a, ":pub") - a.to_unsafe) }
end
