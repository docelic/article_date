lib LibC
  fun strstr(::LibC::Char*, ::LibC::Char*) : ::LibC::Char*
  fun strchr(::LibC::Char*, ::LibC::Char) : ::LibC::Char*
  fun strrchr(::LibC::Char*, ::LibC::Char) : ::LibC::Char*
end

# Basic, high-performance HTML parser.
#
# The parser is not HTML syntax aware. This is also why the common, low-level
# functions are not in the App::Parser::HTML base class, but are contained
# here locally.
#
# The design is a tradeoff for performance and so searching is text-based,
# with minimal necessary and hardcoded HTML rules.
class App::Parser::HTML::Basic < App::Parser::HTML

  # Regex listing known/supported date formats. List values in order of
  # decreased usage/occurrence in practice.
  #
  # Feel free to extend the list. Each regex needs to populate match
  # variables year, month, and day.
  DATE_FORMATS = Regex.new %q|(?<year>\d{4}).(?<month>\d{2}).(?<day>\d{2})|

  # Common/low-level functions:

  def self.find_enclosing(body, from)

    # Opening <
    c = body.to_unsafe[from]
    body.to_unsafe[from] = 0
    if x = LibC.strrchr(body.to_unsafe, 60) # <
      x -= body.to_unsafe
    end
    body.to_unsafe[from] = c

    # Closing >
    if y = LibC.strchr(body.to_unsafe + from, 62) # >
      y -= body.to_unsafe
    end
    body.to_unsafe[from] = c

    (x || 0)..(y || -1)
  end

  # Returns bytes in range [b,e] in `body` of the first tag (out of `tags`) found.
  #
  # This method is very similar to `find_range`, but instead of returning the
  # offsets it returns the String contained in them.
  def self.get_range(body, tags, offset = 0, force_container? = false)
    find_range(body, tags, offset, force_container?).try { |range| body[range] }
  end

  # Returns byte range [b,e] in `body` of the first tag (out of `tags`) found.
  #
  # While `tags` is an array and can be used to search for different tags,
  # its main purpose is to specify searching for lowercase and uppercase
  # version of the same tag. This is faster than invoking upcase/downcase
  # in program code.
  #
  # The range is text-based and includes both HTML tag arguments (if any) and body (if any).
  #
  # ```
  # html = "....<head anything>....</head>"
  # find_range(html, {"head", "HEAD"}, 0, true) # => {4,23}
  # find_range(html, ["nothing"]) # => nil
  # ```
  def self.find_range(body, tags, from = 0, force_container? = false)
    pos_open = find_open(body, tags, from) || return nil

    # NOTE: small overlap here in searched bytes.
    # (pos_open+1) should be (pos_open+1+match_len) to avoid it.
    pos_close = find_closed(body, tags, pos_open+1, force_container?) || -1

    # Return nil if it's an empty tag. There is nothing to parse.
    pos_close > pos_open ? pos_open..pos_close : nil
  end

  # Finds offset of first `tags` found within `body`. `from` controls
  # starting offset.
  #
  # ```
  # str = %q{  <body bgcolor="black">...</body>}
  # p! find_open(str, {"body", "BODY"}, ptr) # => 2
  # ```
  def self.find_open(body, tags, from)
    tags.each do |tag|
      ptr = body.to_unsafe + from
      token = "<#{tag}"
      token_len = token.bytesize
      while ptr = LibC.strstr ptr, token
        ### If we want to pedantically rewind over any whitespace characters:
        #while (9 <= (ptr)[token_len] <= 14) || (ptr)[token_len] == 32
        #  ptr += 1
        #end
        #if (ptr)[token_len] == 47 || (ptr)[token_len] == 62
        ### OR if not, then:
        #
        #     \t \n\ \v \f \r SO SI                 SPACE                    /                     >
        if (9 <= (ptr)[token_len] <= 14) || (ptr)[token_len] == 32 || (ptr)[token_len] == 47 || (ptr)[token_len] == 62
          return ptr - body.to_unsafe
        end
        ptr += 1
      end
    end
    nil
  end

  # Finds offset of first `/tags` found within `body`. `from` controls
  # starting offset. It is usually set to result of `find_open() + 1`.
  #
  # ```
  # str = %q{  <body bgcolor="black">...</body>}
  # p! find_closed(str, {"body", "BODY"}, 3, true) # => 27
  # ```
  def self.find_closed(body, tags, from, force_container? = false)
    from1 = tags.each do |tag|
      ptr = body.to_unsafe + from
      token = "</#{tag}"
      token_len = token.bytesize
      if ptr = LibC.strstr ptr, token
        if force_container?
          return ptr - body.to_unsafe
        else
          break ptr - body.to_unsafe
        end
      end
    end

    ptr = body.to_unsafe + from
    if ptr = LibC.strstr ptr, ">"
      return from1 ? {from1, ptr - body.to_unsafe}.min : ptr - body.to_unsafe
    end

    nil
  end

  # Basic implementation of an iterator that iterates over successive
  # HTML tags.
  class TagIterator
    include Iterator(String)

    @from : Int64

    def initialize(@body : String, @tags : Array(String), @from = 0i64, @force_container = false)
    end

    def next
      if @from < @body.bytesize
        if range = App::Parser::HTML::Basic.find_range @body, @tags, @from, @force_container
          @from = range.end.to_i64 + 1
          return @body[range]
        end
      end
      stop
    end
  end


  # Implements parse worker. Usually spawned in dedicated Fibers.
  def worker
    loop do
      content = @parse_tasks.receive

      print '+' if App::Config.verbose
      tm = Time.monotonic

      date = if 200 <= content["status"] < 300
        # "Strategy" is a method containing the logic for parsing a particular page.
        run_strategy content["body"]
      end
      date ||= Time.utc 1, 1, 1

      tm = Time.monotonic - tm

      @processor.results.send({url: content["url"], title: content["title"], gt: content["gt"], status: content["status"], et: tm, date: date})
      @processor.mutex.synchronize do
        @processor.parse_time += tm
      end
    end
    rescue e : Channel::ClosedError
  end

  # Implements our default strategy for identifying the publish (or equivalent)
  # date in pages.
  def run_strategy(body)
    parse_head body
  end


  # Helper functions:

  # Identifies offset for <head>...</head> and tries to find published date in it.
  def parse_head(body)
    if head = self.class.get_range(body, ["head", "HEAD"], 0, true)

      # List matches in decreasing order of accuracy and popularity
      [ "le:pub" ].each do |token|
        TagIterator.new(head, ["meta", "META"]).each do |meta|
          # Must use if because .try() is only special for nil, not Pointer().null
          if ptr1 = LibC.strstr meta, token
            if ptr2 = LibC.strstr meta, "content="
              DATE_FORMATS.match(meta[(ptr2-meta.to_unsafe)..]).try {|md|
                return Time.utc year: md["year"].to_i, month: md["month"].to_i, day: md["day"].to_i
              }
            end
          end
        end
      end
    end
    nil
  end
end
