module App
  # HTML support for the application's web interface.
  # Module methods simply return embedded HTML strings because the requirements are very simple.
  # (Otherwise Kilt which comes as a Kemal dependency could be used for rendering templates.)
  module HTML

    # Default list of URLs to populate the search box on first visit to the GUI.
    DEFAULT = <<-URLS
    https://arstechnica.com/gadgets/2020/03/amds-7nm-ryzen-4000-laptop-processors-are-finally-here/
    https://github.com/docelic/article_date
    https://github.com/crystal-lang/crystal/releases
    https://en.wikipedia.org/wiki/Crystal_(programming_language)
    https://www.google.com
    https://duckduckgo.com
    http://localhost
    URLS

    # Wraps content in basic HTML layout
    def self.wrap(io)
      HTML.page_header io
      yield io
      HTML.page_footer io
      nil
    end

    # Prints HTML page header
    def self.page_header(io)
      io << <<-HTML
        <html>
          <head>
            <style>
              body { text-align:center; width:90%; margin: 10px auto; font-family: Tahoma, Verdana, Segoe, sans-serif; }
              textarea { width:100%; height: 30%;}
              table { border-collapse: collapse;; width: 100%; border: 1px solid grey;}
              td { border: 1px solid grey; text-align: center;}
              td:nth-child(2) { text-align: left; }
              td:nth-child(4), td:nth-child(5), th:nth-child(4), th:nth-child(5) { text-align: right; }
              hr { margin:20px auto; }
              a { text-decoration: none; }
            </style>
          </head>
          <body>
      HTML
      nil
    end

    # Prints HTML page footer
    def self.page_footer(io)
      io << <<-HTML
          </body>
        </html>
      HTML
      nil
    end

    # Prints HTML input form for URLs to process
    def self.form(io, body = DEFAULT)
      io << <<-HTML
        <form method="post">
          <p><textarea name="urls">#{body}</textarea></p>
          <p><input type="submit" value="Submit"></p>
        </form>
      HTML
      nil
    end

    # Prints HTML <hr>
    def self.hr(io)
      io << <<-HTML
        <hr>
      HTML
      nil
    end

    # Prints results table header
    def self.table_header(io, total_urls)
      io << <<-HTML
        <table>
          <tr>
            <th width="4%">#</th>
            <th>URL<br>(#{total_urls})</th>
            <th width="15%">Date<br>(Y/m/d)</th>
            <th width="10%">Extract<br>(s)</th>
            <th width="10%">GET<br>(s)</th>
            <th width="8%">HTTP<br>Status</th>
            <th width="8%">Parse<br>Method</th>
            <th width="8%">Confidence<br>Score</th>
          </tr>
      HTML
      nil
    end

    # Prints individual results row
    def self.table_row(io, idx, url, title, date, et, gt, status, method, confidence)
      io << %Q{<tr><td>#{idx}</td><td><a href="#{url}">#{title}</a></td><td>#{date.try &.to_s}</td><td>#{"%.4f" % et}</td><td>#{"%.3f" % gt}</td><td>#{status}</td><td>#{method}</td><td>#{confidence}</td></tr>\n}
      nil
    end

    # Prints results table footer
    def self.table_footer(io, rt, et, gt)
      io << <<-HTML
          <tr>
            <th></th>
            <th>TOTAL - real, extract, GET (s)</th>
            <th>#{"%.3f" % rt}</th>
            <th>#{"%.4f" % et}</th>
            <th>#{"%.3f" % gt}</th>
            <th></th>
            <th></th>
          </tr>
        </table>
      HTML
      nil
    end

  end
end
