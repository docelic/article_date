require "bit_array"

require "./parser/html/basic"

# Threaded content retrieval and parsing support.
class App::Processor
  alias Task = Tuple(String, URI)
  alias Content = NamedTuple(url: String, title: String, gt: Time::Span, status: Int32, body: String)
  alias Result  = NamedTuple(url: String, title: String, gt: Time::Span, status: Int32, et: Time::Span, date: Time)

  @urls : Array(String)
  @url_count : Int32
  getter results : Channel(Result)

  getter mutex = Mutex.new
  property :download_time, :parse_time

  def initialize(urls)
    @url_count = urls.size
    @results = Channel(Result).new @url_count
    @download_tasks = Channel(Task).new @url_count
    @parse_tasks = Channel(Content).new @url_count
    @urls = urls.dup

    @download_time = Time::Span.new
    @parse_time = Time::Span.new
  end

  # Starts processing of the requested URLs
  def run
    get_time = Time::Span.new
    parse_time = Time::Span.new

    @urls.each do |url|
      uri = URI.parse url
      next unless domain = uri.host
      @download_tasks.send({url, uri})
    end

    App::Config.downloader.new(self, @download_tasks, @parse_tasks, @url_count).run
    App::Config.parser.new(self, @parse_tasks, @url_count).run
  end

  # Displays HTML result rows
  def html_results(io)
    @urls.size.times do
      r = @results.receive
      HTML.table_row io,
        r["url"],
        r["title"],
        r["date"].try(&.to_s("%Y-%m-%d")),
        r["et"].total_seconds,
        r["gt"].total_seconds,
        r["status"]
    end
  end

  # Closes open connections and channels when object is destroyed
  def finalize
    @download_tasks.close
    @parse_tasks.close
  end

  # Implements parse worker. Usually spawned in dedicated Fibers.
  def parser
    loop do
      data = @parse_tasks.receive

      tm = Time.monotonic
      date = App::Parser::HTML::Basic.new(data["body"]).parse
      tm = Time.monotonic - tm
      @results.send({url: data["url"], gt: data["gt"], status: data["status"], et: tm, date: date})
      @mutex.synchronize do
        @parse_time += tm
      end
    end
    rescue e : Channel::ClosedError
  end
end
