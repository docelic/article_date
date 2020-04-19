module App
  # HTML support for the application's web interface.
  # Module methods simply return embedded HTML strings because the requirements are very simple.
  # (Otherwise Kilt which comes as a Kemal dependency could be used for rendering templates.)
  module HTML

    # Default list of URLs to populate the search box on first visit to the GUI.
    DEFAULT = <<-URLS
    https://www.analyticsvidhya.com/blog/2019/06/comprehensive-guide-text-summarization-using-deep-learning-python/
    https://towardsdatascience.com/text-summarization-using-deep-learning-6e379ed2e89c
    https://machinelearningmastery.com/gentle-introduction-text-summarization/
    https://www.sciencedirect.com/science/article/pii/S1319157819301259
    https://github.com/mbadry1/DeepLearning.ai-Summary
    https://edition.cnn.com/2020/03/12/opinions/oval-office-coronavirus-speech-trumps-worst-bergen/index.html
    https://www.nytimes.com/2020/03/11/us/politics/trump-coronavirus-speech.html
    https://www.caranddriver.com/reviews/a21786823/2019-audi-q8-first-drive-review/
    https://www.topgear.com/car-reviews/audi/q8
    https://www.youtube.com/watch?v=mii6NydPiqI
    https://gardenerspath.com/how-to/beginners/first-vegetable-garden/
    https://lifehacker.com/the-seven-easiest-vegetables-to-grow-for-beginner-garde-1562176780
    https://www.gardeningknowhow.com/edible/vegetables/vgen/vegetable-gardening-for-beginners.htm
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
              body { text-align:center; width:80%; margin: 10px auto; font-family: Tahoma, Verdana, Segoe, sans-serif; }
              textarea { width:100%; height: 30%;}
              table { border-collapse: collapse;; width: 100%; border: 1px solid grey;}
              td { border: 1px solid grey; text-align: center;}
              td:nth-child(1) { text-align: left; }
              td:nth-child(3), td:nth-child(4), th:nth-child(3), th:nth-child(4) { text-align: right; }
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
    def self.table_row(io, url, title, date, et, gt, status)
      io << %Q{<tr><td><a href="#{url}">#{title}</a></td><td>#{date}</td><td>#{"%.4f" % et}</td><td>#{"%.3f" % gt}</td><td>#{status}</td></tr>\n}
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
