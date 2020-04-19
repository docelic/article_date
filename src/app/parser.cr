# Base class for all content parsers.
abstract class App::Parser
  @processor : App::Processor
  @parse_tasks : Channel(App::Processor::Content)

  def initialize(@processor, @parse_tasks, capacity)
  end

  # Implements parse worker. Usually spawned in dedicated Fibers.
  def run
    App::Config.parsers.times do spawn { worker } end
  end

  abstract def worker
end
