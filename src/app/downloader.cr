# Base class for all download clients.
#
# URLs do not necessarily have to be retrieved from the web using a HTTP client.
# Different types of downloaders could load URLs from local cache for reparsing,
# or they could download page data via service-specific APIs (e.g. Wikipedia API).
abstract class App::Downloader

  @processor : App::Processor
  @download_tasks : Channel(App::Processor::Task)
  @parse_tasks : Channel(App::Processor::Content)

  def initialize(@processor, @download_tasks, @parse_tasks, capacity)
  end

  # Implements download worker. Usually spawned in dedicated Fibers.
  def run
    App::Config.downloaders.times do spawn { worker } end
  end

  abstract def worker
end
