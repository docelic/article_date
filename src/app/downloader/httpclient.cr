# HTML downloader implemented using Crystal's HTTP::Client.
#
# Supports basic functions like HTTP Keep-Alive, redirections,
# configurable number of connections per domain, and configurable
# timeouts.
#
# It is limited to HTTP protocol version which is supported by Crystal.
class App::Downloader::HTTPClient < App::Downloader

  @mutex = Mutex.new

  def initialize(@processor, @download_tasks, @parse_tasks, capacity)
    super
    @clients = Hash(String, Array(HTTP::Client)).new initial_capacity: capacity
    @usage = Hash(String, BitArray).new initial_capacity: capacity
  end

  def worker
    loop do
      idx, url, uri = @download_tasks.receive
      domain = uri.host.not_nil!

      @mutex.synchronize do
        @clients[domain] ||= Array(HTTP::Client).new App::Config.connections
        @usage[domain] ||= BitArray.new App::Config.connections
      end

      # Find free downloader
      di = loop do
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

      title = url

      # Instantiate HTTP::Client if missing
      client = @mutex.synchronize do
        @clients[domain][di]? || begin
          (di-@clients[domain].size+1).times do
            c = HTTP::Client.new uri
            c.connect_timeout= App::Config.connect_timeout
            c.dns_timeout    = App::Config.dns_timeout
            c.read_timeout   = App::Config.read_timeout
            c.write_timeout  = App::Config.write_timeout
            @clients[domain].push c
          end
          @clients[domain][di]
        end
      end

      tm = Time.monotonic
      print '.' if App::Config.verbose
      get = begin
        client.get uri.full_path.empty? ? "/" : uri.full_path
      rescue e : Socket::Addrinfo::Error | OpenSSL::SSL::Error | IO::TimeoutError | IO::Error
        title += " - #{e.to_s}"
        @clients[domain].delete client
        HTTP::Client::Response.new 422
      end
      tm = Time.monotonic - tm

      @processor.mutex.synchronize do
        @processor.download_time += tm
      end
      @usage[domain][di] = false

      if 301 <= get.status_code <= 308
        # Means we got a redirect; requeue with new URL
        @download_tasks.send({idx, url, URI.parse get.headers["location"]})
      else
        # We want to pass even invalid responses to parser tasks;
        # it is up to them to bail out if content is not there.
        @parse_tasks.send App::Processor::Content.new idx: idx, url: url, title: title, gt: tm, response: get
      end
    end
    rescue e : Channel::ClosedError
  end

  def finalize
    @clients.each_value &.each &.close
  end
end
