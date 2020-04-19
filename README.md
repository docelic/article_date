# Introduction

This repository contains a small, self-contained application for retrieving
web pages and parsing their creation or modification dates.

## Running the app

To run the application, run `shards` to install dependencies and then:

```bash
crystal [run --release] src/app.cr [-- options]

OR

shards build [--release]
./bin/app [options]
```

The application supports the following options:

```
    -c, --connections    (50) - Concurrent connections per host
    -d, --downloaders   (200) - Number of downloading threads
    -h, --help                - This help
    -p, --parsers        (10) - Number of date parsing threads
    -v, --verbose     (false) - Print a dot (.) on each download
                                Print a plus (+) on each parse

    -C, --connect-timeout (5) - Set connect timeout (s)
    -D, --dns-timeout     (5) - Set DNS timeout (s)
    -R, --read-timeout    (5) - Set read timeout (s)
    -W, --write-timeout   (5) - Set write timeout (s)
    -T, --timeout         (5) - Set all timeouts (s)
```

Complete example:

```bash
git clone https://github.com/docelic/article_date
cd article_date
shards build --release
bin/app -c 50 -d 200
```

## Usage

Once the app is started with the desired options, visit
[http://localhost:3000/](http://localhost:3000/) in the browser.

The minimal HTML user interface is provided by Kemal and it provides
a textarea for entering page URLs, one per line.

Clicking "Submit" will process the data and display the results.
A sort of real-time update is achieved by printing data to the
response IO in real-time, allowing the browser to display result
rows in incremental chunks instead of having to wait for all data
to be processed.

## Runtime and results

When the application starts, it will print a summary of the running
configuration to the screen. Also, if option -v is provided, it will
print a dot ('.') to the screen for each downloaded file.

As URLs are processed, each result row in the browser
displays the following values:

1. Page URL
2. Parsed creation/modification date. If no date was determined, it is
reported as "0001-01-01"
3. Elapsed time for parsing the date (this value includes all Fiber
wait times, but as almost all methods invoked should be non-blocking,
this value is generally close to the real algorithm execution time)
4. Elapsed time for downloading the page (this value includes all Fiber
wait times, e.g. times waiting for web servers to respond as well as
fibers to be scheduled on the CPU. As such it is regularly
higher than the amount of time spent in actual execution)
5. HTTP response status code

The footer of the table also contains 3 summarized values:

1. Total real (wallclock) time
2. Sum of all parsing times
3. Sum of all download times

Wallclock time is useful for determining bottom-line performance.

Parsing times are useful for identifying potential improvements in the
parsing methods on particular types of pages.

Download times, if very high, are useful for identifying
that the thread settings (options -d and -p) may be suboptimal
and could be adjusted. Alternatively if they are very low, the
number of threads could be increased.

When the processing is complete, all open downloader connections and
Fibers are terminated.

## App design

The app is based on Fibers and Channels.

A group of N (--downloader) Fibers works on the input URLs, processing
each one while taking advantage of basic HTTP Keep-Alive implementation
and maintaining at most N (--connections) HTTP::Clients open for each
individual domain.

Parallel connections to the same host are not created up-front, but
are instantiated only if needed to crawl multiple pages from the same
domain simultaneously.

The app is intended to run N (--downloader) download
fibers in parallel. However, if the input list is heavily sorted by
domain the performance may be reduced to N (--connections).
In such cases, either set options -d and -c to the same value or
randomize the input list (e.g. `sort -R <file>`).

As each downloader downloads its page, it sends the intermediate data
over the appropriate Channel through to the parser processes, and then
waits for the next page to download.

The parser processes receive downloaded data and try to determine the
page creation or modification date using various parsing strategies.
The current design of the parsing and extraction system is documented
in the file *PARSING.md*.

As each parser finishes scanning through the page, it sends the final
results and statistics through the results Channel and then waits for another
page to parse.

### In more general terms

The implemented design based on downloaders, channels, and parser threads is
chosen on the idea that a real-world, larger system could use a
similar architecture on a larger scale.

For example, the downloader processes might be advanced clients capable
of parsing JavaScript-heavy/SPA pages, re-parsing stored content instead
of downloading it again, and/or using various APIs instead of getting data
through crawling (e.g. search engines get data from Wikipedia via
API, not downloading HTML).

These processes would then be sending contents via message passing or
queueing systems for further processes down the line, of which the date
parsing ones might be just one type of consumer.

### Improvements

In a more complete, non-prototype implementation, a couple improvements
could be added:

- More per-domain crawling limits and/or bandwidth caps

- Keeping track of which parsing strategies had the best success rate on
particular domains and/or subdirectories within domains. The order in
which the parsing strategies are run could then be dynamically adjusted
for best performance.

- Adding a confidence score to the parsing strategies so that the date
parsing would continue until desired accuracy is reached. This would
allow the value to be tuned dynamically and/or for the parsing to happen
twice (first time quickly, second time more accurately).

Thanks!
