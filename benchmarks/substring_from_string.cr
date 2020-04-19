require "benchmark"

a = "testtest" * 1_000_000

class Substring
  # str_header = str.as(Int32*)

  #@header : Int32*

  # Original values
  #getter otype     : Int32
  getter obytesize : Int32
  #getter osize     : Int32

  # New values
  #getter type     : Int32
  getter bytesize : Int32
  #getter size     : Int32

  # Original value of null-byte
  #getter byte      : UInt8

  @from : Int32
  @to   : Int32

  def initialize(@string : String, @from = 0, to : Int32? = nil, size : Int32? = nil)
    #@otype, @obytesize, @osize = @header[0], @header[1], @header[2]
    #@type, @bytesize, @size = @otype, @obytesize, @osize
    @bytesize = @obytesize = @string.as(Int32*)[1]
    if to
      #@to = @string.to_unsafe + to
      @to = to
    elsif size
      #@to = @string.to_unsafe + @from + size
      @to = @from + size
    else
      @to = @obytesize - 1
    end

    size = @to - @from # Or absolute value from from=0?

    # Just for compiler; value is ignored
    #@byte = @string.to_unsafe[@from + size]

    self.bytesize = size
  end

  def bytesize=(arg)
    #@header[1] = arg
    @string.as(Int32*)[1] = arg
    #@byte = @string.to_unsafe[@from + arg]
    #@string.to_unsafe[@from + arg + 1] = 0
  end

  def to_unsafe
    @string.to_unsafe + @from
  end
  def to_slice
    Slice.new(to_unsafe, @bytesize, read_only: true)
  end

  def to_s : String
    @string[@from..(@to-@from)]
  end
  def to_s(io : IO) : Nil
    io.write_utf8(to_slice)
  end

  #delegate :to_s, :inspect, to: @string

  # Returns original string to original state
  def reset
    #@byte.try { |b| @string.to_unsafe[@bytesize + 1] = b }
    #@header[0] = @otype
    @string.as(Int32*)[1] = @obytesize
    #@header[2] = @osize
  end

  #def finalize; reset end
end

Benchmark.ips(warmup:1) do |x|
  x.report("String#[0..100]") { a[0..1]; nil }
  x.report("Substring 0-100") { Substring.new(a, from: 0, to: 1).reset; nil }
end

Benchmark.ips(warmup:1) do |x|
  x.report("String#[250..600]") { a[250..251]; nil }
  x.report("Substring 250-600") { Substring.new(a, from: 250, to: 251).reset; nil }
end

Benchmark.ips(warmup:1) do |x|
  x.report("String#[100k-110k]") { a[100000..100001]; nil }
  x.report("Substring 100k-110k") { Substring.new(a, from: 100000, to: 100001).reset; nil }
end
