module App
  # HTML support for the application's web interface.
  # Module methods simply return embedded HTML strings because the requirements are very simple.
  # (Otherwise Kilt which comes as a Kemal dependency could be used for rendering templates.)
  module HTML

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
              body { text-align:center; width:80%; margin: 10px auto; font-family: Tahoma, Verdana, Segoe, sans-serif; }
              textarea { width:100%; height: 30%;}
              table { border-collapse: collapse;; width: 100%; border: 1px solid grey;}
              td { border: 1px solid grey; text-align: center;}
              td:nth-child(1) { text-align: left; }
              td:nth-child(3), td:nth-child(4), th:nth-child(3), th:nth-child(4) { text-align: right; }
              hr { margin:20px auto; }
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
    def self.form(io, body = "")
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
            <th>URL<br>(#{total_urls})</th>
            <th width="15%">Date<br>(Y/m/d)</th>
            <th width="10%">Extract<br>(s)</th>
            <th width="10%">GET<br>(s)</th>
            <th width="8%">HTTP<br>Status</th>
          </tr>
      HTML
      nil
    end

    # Prints individual results row
    def self.table_row(io, url, date, et, gt, status)
      #io << %Q{<tr><td>#{url}</td><td>#{date}</td><td>#{"%.3f" % et}</td><td>#{"%.3f" % gt}</td><td>#{status}</td></tr>\n}
      io << %Q{<tr><td>#{url}</td><td>-</td><td>#{"%.3f" % et}</td><td>#{"%.3f" % gt}</td><td>#{status}</td></tr>\n}
      nil
    end

    # Prints results table footer
    def self.table_footer(io, rt, et, gt)
      io << <<-HTML
          <tr>
            <th>TOTAL - real, extract, GET (s)</th>
            <th>#{"%.3f" % rt}</th>
            <th>#{"%.3f" % et}</th>
            <th>#{"%.3f" % gt}</th>
            <th></th>
          </tr>
        </table>
      HTML
      nil
    end

  end
end
