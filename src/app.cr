require "kemal"
require "uri"

require "./app/html"
require "./app/parsing"

# Web page downloader and creation date parser
module App
  VERSION = "0.1.0"

  # Application config with predefined defaults.
  class Config
    class_property connections = 50
    class_property downloaders = 200
    class_property parsers = 10
    class_property verbose = false
    def self.to_s(io)
      io << <<-END
      Connections per host/domain: #{@@connections}
      Downloader threads: #{@@downloaders}
      Date parser threads: #{@@parsers}
      Verbose: #{@@verbose}

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
          -c, --connections (50)    - Concurrent connections per host
          -d, --downloaders (200)   - Number of downloading threads
          -h, --help                - This help
          -p, --parsers     (10)    - Number of date parsing threads
          -v, --verbose     (false) - Print a dot (.) on each download

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
        data = Parsing.new urls, App::Config
        data.process
        data.html_results io

        # Note: real_time includes the time needed to send
        # table rows to the browser.
        real_time = Time.monotonic - tm

        HTML.table_footer io,
          real_time.total_seconds,
          data.parsing_time.total_seconds,
          data.download_time.total_seconds

        HTML.hr io
      end
      HTML.form io, urls.join "\n"
    end
  end

  Config.to_s STDOUT
  ::Kemal.run
end
