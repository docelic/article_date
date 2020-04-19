# HTML downloader implemented using Crystal's HTTP::Client.
#
# Supports basic functions like HTTP Keep-Alive, configurable
# number of connections per domain, and configurable timeouts.
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
      url, uri = @download_tasks.receive
      domain = uri.host.not_nil!

      @mutex.synchronize do
        @clients[domain] ||= Array(HTTP::Client).new App::Config.connections
        @usage[domain] ||= BitArray.new App::Config.connections
      end

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

      title = url

      # Instantiate HTTP::Client if missing
      client = @mutex.synchronize do
        @clients[domain][idx]? || begin
          c = @clients[domain][idx..idx] = HTTP::Client.new uri
          c.connect_timeout= App::Config.connect_timeout
          c.dns_timeout    = App::Config.dns_timeout
          c.read_timeout   = App::Config.read_timeout
          c.write_timeout  = App::Config.write_timeout
          c
        end
      end

      tm = Time.monotonic
      print '.' if App::Config.verbose
      get = begin
        client.get uri.path.empty? ? "/" : uri.path
      rescue e : Socket::Addrinfo::Error | OpenSSL::SSL::Error | IO::TimeoutError
        title += " - #{e.to_s}"
        @clients[domain].delete client
        HTTP::Client::Response.new 422
      end
      tm = Time.monotonic - tm

      @parse_tasks.send App::Processor::Content.new url: url, title: title, gt: tm, status: get.status_code, body: get.body
      @processor.mutex.synchronize do
        @processor.download_time += tm
      end
      @usage[domain][idx] = false
    end
    rescue e : Channel::ClosedError
  end

  def finalize
    @clients.each_value &.each &.close
  end
end