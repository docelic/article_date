require "bit_array"

module App

  # Generic content parsing support, including worker methods.
  class Parsing

    alias Task = Tuple(String, URI)
    alias Content = NamedTuple(url: String, gt: Time::Span, status: Int32, body: String)
    alias Result  = NamedTuple(url: String, gt: Time::Span, status: Int32, et: Time::Span, date: Time)

    @urls : Array(String)
    @download_tasks : Channel(Task)
    @parsing_tasks : Channel(Content)
    @results : Channel(Result)

    getter :download_time, :parsing_time

    @mutex = Mutex.new

    def initialize(urls, @connections : Int32, @downloaders : Int32, @parsers : Int32, @verbose : Bool)
      url_count = urls.size
      @clients = Hash(String, Array(HTTP::Client)).new initial_capacity: url_count
      @usage = Hash(String, BitArray).new initial_capacity: url_count
      @results = Channel(Result).new url_count
      @download_tasks = Channel(Task).new url_count
      @parsing_tasks = Channel(Content).new url_count
      @urls = urls.dup

      @download_time = Time::Span.new
      @parsing_time = Time::Span.new
    end
    def initialize(urls, config : Config.class)
      initialize urls, config.connections, config.downloaders, config.parsers, config.verbose
    end

    # Starts processing of the requested URLs
    def process
      get_time = Time::Span.new
      parse_time = Time::Span.new

      @urls.each do |url|
        uri = URI.parse url
        next unless domain = uri.host
        @clients[domain] ||= Array(HTTP::Client).new @connections
        @usage[domain] ||= BitArray.new @connections
        @download_tasks.send({url, uri})
      end

      @downloaders.times do spawn { downloader } end
      @parsers.times do spawn { parser } end
    end

    # Displays HTML result rows
    def html_results(io)
      @urls.size.times do
        r = @results.receive
        HTML.table_row io,
          r["url"],
          r["date"].to_s("%Y-%m-%d"),
          r["et"].total_seconds,
          r["gt"].total_seconds,
          r["status"]
      end
    end

    # Closes open connections and channels when object is destroyed
    def finalize
      @clients.each_value &.each &.close
      @download_tasks.close
      @parsing_tasks.close
    end

    # Implements download worker. Usually spawned in dedicated Fibers.
    def downloader
      loop do
        print '.' if @verbose
        url, uri = @download_tasks.receive
        domain = uri.host.not_nil!

        # Find free downloader
        idx = loop do
          i = nil
          @mutex.synchronize do
            if i = @usage[domain].index false
              @usage[domain][i] = true
            end
          end
          if i
            break i
          else
            sleep 0.1
          end
        end

        # Instantiate HTTP::Client if missing
        client = @clients[domain][idx]? || (@clients[domain][idx..idx] = HTTP::Client.new uri)

        tm = Time.monotonic
        begin
          get = client.get uri.path.empty? ? "/" : uri.path
        rescue e : Socket::Addrinfo::Error | OpenSSL::SSL::Error
          get = HTTP::Client::Response.new 422
          url += " - #{e.to_s}"
          @clients[domain].delete client
        end
        get
        tm = Time.monotonic - tm

        @mutex.synchronize do
          @download_time += tm
        end

        @parsing_tasks.send Content.new url: url, gt: tm, status: get.status_code, body: get.body
        @usage[domain][idx] = false
      end
      rescue e : Channel::ClosedError
    end

    # Implements parsing worker. Usually spawned in dedicated Fibers.
    def parser
      loop do
        data = @parsing_tasks.receive

        tm = Time.monotonic
        # TODO - add parsing strategies
        tm = Time.monotonic - tm
        @results.send({url: data["url"], gt: data["gt"], status: data["status"], et: Time::Span.new, date: Time.local})
        @mutex.synchronize do
          @parsing_time += tm
        end
      end
      rescue e : Channel::ClosedError
    end
  end
end
