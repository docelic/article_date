class Substring
  # str_header = str.as(Int32*)

  @header : Int32*

  # Original values
  getter otype     : Int32
  getter obytesize : Int32
  getter osize     : Int32

  # New values
  getter type     : Int32
  getter bytesize : Int32
  getter size     : Int32

  # Original value of null-byte
  getter byte      : UInt8

  @from : Int32
  @to   : Int32

  def initialize(@string : String, @from = 0, to : Int32? = nil, size : Int32? = nil)
    @header = @string.as(Int32*)
    @otype, @obytesize, @osize = @header[0], @header[1], @header[2]
    @type, @bytesize, @size = @otype, @obytesize, @osize
    if to
      #@to = @string.to_unsafe + to
      @to = to
    elsif size
      #@to = @string.to_unsafe + @from + size
      @to = @from + size
    else
      @to = @string.bytesize - 1
    end

    size = @to - @from # Or absolute value from from=0?

    # Just for compiler; value is ignored
    @byte = @string.to_unsafe[@from + size]

    self.bytesize = size
  end

  def bytesize=(arg)
    p :SET_SIZE_TO, arg
    @header[1] = arg
    @byte = @string.to_unsafe[@from + arg]
    @string.to_unsafe[@from + arg + 1] = 0
  end

  def to_unsafe
    p :UNSA, @from
    @string.to_unsafe + @from
  end
  def to_slice
    p :SLIC, @bytesize
    Slice.new(to_unsafe, @bytesize, read_only: true)
  end

  def to_s : String
    @string[@from..(@to-@from)]
  end
  def to_s(io : IO) : Nil
    io.write_utf8(to_slice)
  end

  delegate :to_s, :inspect, to: @string

  # Returns original string to original state
  def finalize
    @byte.try { |b| @string.to_unsafe[@bytesize + 1] = b }
    @header[0] = @otype
    @header[1] = @obytesize
    @header[2] = @osize
  end
end

s = "TEST".chars.join
p! s

ss = Substring.new s, from: 1, to: 3
p! ss.to_s
p! ss.to_s STDOUT
p! ss.inspect






