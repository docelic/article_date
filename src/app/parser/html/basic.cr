lib LibC
  fun strstr(::LibC::Char*, ::LibC::Char*) : ::LibC::Char*
  # Already used/defined in Crystal's string.cr:
  #fun memchr(x0 : Void*, c : Int, n : SizeT) : Void*
end

# Basic HTML parser.
#
# The parser is not HTML syntax aware, it only adheres to basic HTML parsing rules.
# Because it does not qualify as a true HTML parser, its low level functions are
# defined here locally instead of being defined in the App::Parser::HTML base class.
#
# The implemented design uses 2 or 3 LibC functions. This is not necessary,
# it was an experiment to see how it would work.
class App::Parser::HTML::Basic < App::Parser::HTML

  # Regex listing known/supported date formats.
  # List the searches in order of decreasing usage/occurrence in practice.
  DATE_FORMATS = {
    { Regex.new("(?<year>\\d{4})([-\\/])(?<month>\\d{2})\\2(?<day>\\d{2})"), nil },
    { Regex.new("(?<month>[A-Z][a-z]{2}) (?<day>\\d{1,2}),? (?<year>\\d{4})"), "%Y-%b-%d" },
    { Regex.new("(?<month>[A-Z][a-z]{3,}) (?<day>\\d{1,2}),? (?<year>\\d{4})"), "%Y-%^b-%d" },
  }

  # Implements parse worker. Usually spawned in dedicated Fibers.
  def worker
    loop do
      content = @parse_tasks.receive

      print '+' if App::Config.verbose
      tm = Time.monotonic

      method, confidence, date = if content["response"].success?
        # "Strategy" is a method containing the logic for parsing a particular page.
        run_strategy content["response"].body
      else
        {"-", 0.0, nil}
      end

      tm = Time.monotonic - tm

      @processor.results.send({
        idx: content["idx"],
        url: content["url"],
        title: content["title"],
        gt: content["gt"],
        status: content["response"].status_code,
        et: tm,
        date: date,
        method: method,
        confidence: confidence,
      })
      @processor.mutex.synchronize do
        @processor.parse_time += tm
      end
    end
    rescue e : Channel::ClosedError
  end

  # Implements our default strategy for identifying the publish (or equivalent)
  # date in pages.
  def run_strategy(body)
    parse_head(body) ||
      parse_scripts(body) ||
        find_first_date_string(body) ||
          {"-", 0.0, nil}
  end

  # Identifies offset for <head>...</head> and tries to find published date in it.
  def parse_head(body)
    if head = App::Parser::HTML::Basic.get_range(body, {"<head", "<HEAD"}, {"</head", "</HEAD"}, 0, true)
      # List the searches in decreasing order of accuracy and popularity
      TagIterator.new(head, {"<meta", "<META"}, {"</meta", "</META"}).each do |meta|
        { {"article:pub",1.0}, {"pub",0.9}, {"create",0.9}, {"modif",0.9} }.each do |token, confidence|
          if ptr1 = LibC.strstr meta, token
            if ptr2 = LibC.strstr meta, "content="
              f = meta.byte_index_to_char_index(ptr2-meta.to_unsafe).not_nil!
              if time = date_string_to_time meta[f..]
                #p! time
                return {"head-meta", confidence, time}
              end
            end
          end
        end
      end
    end
    nil
  end

  TYPE_JSON = Regex.new %q{(["'])application/(?:ld+)?json\1}
  def parse_scripts(body)
    TagIterator.new(body, {"<script", "<SCRIPT"}, {"</script", "</SCRIPT"}, 0i64, true).each do |script|
      attributes = script[0..(script.index '>')]
      if ptr1 = LibC.strstr(attributes, "application/json") || LibC.strstr(attributes, "application/ld+json")
        if ptr2 = LibC.strstr(script, "datePublished")
          i = script.byte_index_to_char_index(ptr2-script.to_unsafe).not_nil!.to_i32
          if time = date_string_to_time script, i
            return {"json-datePublished", 1.0, time}
          end
        end
      end
    end
    nil
  end

  def find_first_date_string(body)
    {"first", 0.0, date_string_to_time body}
  rescue e : ArgumentError
    {"first", 0.0, nil}
  end

  # Basic implementation of an iterator that iterates over successive
  # HTML tags.
  class TagIterator
    include Iterator(String)

    @from : Int64
    @tags_open : Tuple(String,String) | Array(String)
    @tags_closed : Tuple(String,String) | Array(String)

    def initialize(@body : String, @tags_open, @tags_closed, @from = 0i64, @force_container = false)
    end

    def next
      if range = App::Parser::HTML::Basic.find_range @body, @tags_open, @tags_closed, @from, @force_container
        @from = range.end.to_i64
        f = @body.byte_index_to_char_index(range.begin.to_i64).not_nil!
        t = @body.byte_index_to_char_index(range.end.to_i64).not_nil!
        return @body[f..t]
      end
      stop
    end
  end

  # Common/low-level functions:

  # Finds any one of `tags_open` and `tags_closed` pairs and returns the
  # string contained between them.
  #
  # This method is similar to `find_range`, but instead of returning the
  # byte offsets it returns the String contained in them.
  def self.get_range(body, tags_open, tags_closed, offset = 0, force_container? = false)
    report = if tags_open.includes? "<head" ; true else false end
    if offset >= body.bytesize
      return nil
    end
    find_range(body, tags_open, tags_closed, offset, force_container?).try do |range|
      body.byte_index_to_char_index(range.begin).try do |b|
        body.byte_index_to_char_index(range.end).try do |e|
          return body[b..e]
        end
      end
    end
    nil
  end

  # Returns byte range [b,e] in `body` of the content between the first
  # `tags_open` and `tags_closed` pair found.
  #
  # While `tags_*` are arrays and can be used to search for different tags,
  # their main purpose is to specify searching for lowercase and uppercase
  # version of the same tag. This is faster than invoking upcase/downcase
  # in program code.
  #
  # The range is byte-based and includes both HTML tag arguments (if any) and
  # body (if any).
  #
  # ```
  # html = "....<head anything>....</head>"
  # find_range(html, {"<head", "<HEAD"}, {"</head", "</HEAD"}, 0, true) # => {4,23}
  # find_range(html, ["<nothing"], ["</nothing"]) # => nil
  # ```
  def self.find_range(body, tags_open, tags_closed, from = 0, force_container? = false)
    pos_open = find_open(body, tags_open, from) || return nil

    # NOTE: small overlap here in searched bytes.
    # (pos_open+1) should be (pos_open+1+match_len) to avoid it,
    # but match_len is not known here.
    pos_close = find_closed(body, tags_closed, pos_open+1, force_container?) || -1

    # Return nil if it's an empty tag. There is nothing to parse.
    pos_close > pos_open ? pos_open..pos_close : nil
  end

  # Finds byte offset of first `tags` found within `body`. `from` controls
  # the starting offset.
  #
  # ```
  # str = %q{  <body bgcolor="black">...</body>}
  # p! find_open(str, {"<body", "<BODY"}, ptr) # => 2
  # ```
  def self.find_open(body, tags, from)
    tags.each do |tag|
      ptr = body.to_unsafe + from
      tag_len = tag.bytesize
      while ptr = LibC.strstr ptr, tag
        ### If we want to pedantically rewind over any whitespace characters:
        #while (9 <= (ptr)[tag_len] <= 14) || (ptr)[tag_len] == 32
        #  ptr += 1
        #end
        #if (ptr)[tag_len] == 47 || (ptr)[tag_len] == 62
        ### OR if not, then:
        #
        #     \t \n\ \v \f \r SO SI                 SPACE                    /                     >
        if (9 <= (ptr)[tag_len] <= 14) || (ptr)[tag_len] == 32 || (ptr)[tag_len] == 47 || (ptr)[tag_len] == 62
          return ptr - body.to_unsafe + tag_len
        end
        ptr += 1
      end
    end
    nil
  end

  # Finds byte offset of first `/tags` found within `body`. `from` controls
  # the starting offset. It is usually set to result of `find_open() + 1`.
  #
  # ```
  # str = %q{  <body bgcolor="black">...</body>}
  # p! find_closed(str, {"</body", "</BODY"}, 3, true) # => 27
  # ```
  def self.find_closed(body, tags, from, force_container? = false)
    from1 = tags.each do |tag|
      ptr = body.to_unsafe + from
      tag_len = tag.bytesize
      if ptr = LibC.strstr ptr, tag
        if force_container?
          return ptr - body.to_unsafe - 1
        else
          break ptr - body.to_unsafe - 1
        end
      end
    end

    ptr = body.to_unsafe + from
    if ptr = LibC.memchr(ptr, 62, body.bytesize - from).try &.as(::LibC::Char*) # '>'
      return from1 ? {from1, ptr - body.to_unsafe}.min : ptr - body.to_unsafe
    end

    nil
  end

  # Returns corresponding Time object or nil if no date was matched.
  private def date_string_to_time(body, offset=0i32)
    DATE_FORMATS.each do |pattern, format|
      if md = pattern.match body, offset
        if format
          return Time.parse_utc "#{md["year"]}-#{md["month"]}-#{md["day"]}", format
        else
          return Time.utc year: md["year"].to_i, month: md["month"].to_i, day: md["day"].to_i
        end
      end
    end
    nil
  end
end
