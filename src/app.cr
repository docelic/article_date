require "kemal"
require "uri"

require "./app/parser"
require "./app/parser/html"
require "./app/processor"
require "./app/downloader"
require "./app/html"
require "./app/downloader/httpclient"
require "./app/parser/html/basic"

# Web page downloader and published-date parser
module App
  VERSION = "0.1.0"

  # Application config with predefined defaults.
  class Config
    class_property connections     = 50
    class_property downloaders     = 200
    class_property parsers         = 10
    class_property verbose         = false
    class_property downloader      = App::Downloader::HTTPClient
    class_property parser          = App::Parser::HTML::Basic

    class_property connect_timeout : Time::Span = 5.seconds
    class_property dns_timeout     : Time::Span = 5.seconds
    class_property read_timeout    : Time::Span = 5.seconds
    class_property write_timeout   : Time::Span = 5.seconds

    def self.to_s(io)
      io << <<-END

      Downloader class: #{@@downloader}
      Downloader threads: #{@@downloaders}
      Connections per host/domain: #{@@connections}
      Timeouts (s) (connect, dns, read, write): #{[@@connect_timeout,@@dns_timeout,@@read_timeout,@@write_timeout].join ", "}

      Parser class: #{@@parser}
      Date parser threads: #{@@parsers}

      Verbose: #{@@verbose}

      Use --help for config options.


      END
    end
  end

  begin
    OptionParser.parse(ARGV) do |opts|
      opts.on("-c N", "--connections N") { |n| Config.connections = n.to_i }
      opts.on("-d N", "--downloaders N") { |n| Config.downloaders = n.to_i }
      opts.on("-h", "--help")            {     App.display_help_and_exit }
      opts.on("-p N", "--parsers N")     { |n| Config.parsers = n.to_i }
      opts.on("-v", "--verbose")         {     Config.verbose = true }

      opts.on("-C N", "--connect-timeout N"){ |n| Config.connect_timeout = n.to_f.seconds }
      opts.on("-D N", "--dns-timeout N")    { |n| Config.dns_timeout     = n.to_f.seconds }
      opts.on("-R N", "--read-timeout N")   { |n| Config.read_timeout    = n.to_f.seconds }
      opts.on("-W N", "--write-timeout N")  { |n| Config.write_timeout   = n.to_f.seconds }

      opts.on("-T N", "--timeout N")        { |n| Config.connect_timeout = n.to_f.seconds
                                                  Config.dns_timeout     = n.to_f.seconds
                                                  Config.read_timeout    = n.to_f.seconds
                                                  Config.write_timeout   = n.to_f.seconds }

      opts.unknown_args do |args| display_help_and_exit 1 unless args.empty? end
    end
  rescue ex : OptionParser::InvalidOption
    STDERR.puts ex.message
    exit 1
  end
  def self.display_help_and_exit(status=0)
    (status == 0 ? STDOUT : STDERR) << <<-HELP
      Usage: [<options>...]

      Options:
          -c, --connections    (50) - Concurrent connections per host
          -d, --downloaders   (200) - Number of downloading threads
          -h, --help                - This help
          -p, --parsers        (10) - Number of date parser threads
          -v, --verbose     (false) - Print a dot (.) on each download
                                      Print a plus (+) on each parse

          -C, --connect-timeout (5) - Set connect timeout (s)
          -D, --dns-timeout     (5) - Set DNS timeout (s)
          -R, --read-timeout    (5) - Set read timeout (s)
          -W, --write-timeout   (5) - Set write timeout (s)
          -T, --timeout         (5) - Set all timeouts (s)

      HELP
    exit status
  end

  # Displays input form
  get "/" do |env|
    HTML.wrap(env.response) { |io| HTML.form io }
  end

  # Processes URLs and displays results 
  post "/" do |env|
    urls = env.params.body["urls"]?.try(&.split(/[\r\n]+/).select(/\S/)) || Array(String).new

    HTML.wrap(env.response) do |io|
      unless urls.empty?
        HTML.table_header io, urls.size

        tm = Time.monotonic
        processor = Processor.new urls
        processor.run
        processor.html_results io

        # Note: real_time includes the time needed to send
        # table rows to the browser.
        real_time = Time.monotonic - tm

        HTML.table_footer io,
          real_time.total_seconds,
          processor.parse_time.total_seconds,
          processor.download_time.total_seconds

        HTML.hr io
      end
      HTML.form io, urls.join "\n"
    end
    puts if App::Config.verbose
  end

  Config.to_s STDOUT
  ::Kemal.run
end
