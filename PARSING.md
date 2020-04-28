# Parsing and extraction

## Introduction

The first task in designing the parsing strategy was to determine the
performance of various functions that would probably always be used,
regardless of specifics.

A series of files in the benchmarks/ directory implements those tests.
Many tests check performance of C-level functions, and a couple LibC
functions are used in the implementation (explained below).

### Processors, Downloaders, and Parsers

As mentioned in *README.md*, the application  is implemented as a possible
mini model of a larger, real implementation. It is structured in the
following way:

A "processor" performs basic processing on the input URLs (such as parsing
string URLs into URI instances) and then sends individual units of work
to "Downloaders".

Downloaders implement the common downloader interface and are in charge
of obtaining the content to parse. One currently existing downloader is
based on Crystal's HTTP::Client, but any additional downloaders could
be implemented. E.g. to use Curl bindings and support HTTP/2,
download pages via service-specific APIs instead of HTML, or load
contents from local cache. Once content is obtained, it is passed on to
"Parsers".

Parsers are in charge of processing the input text. One
currently existing parser is called "Basic" and is explained below.
Other parsers could be written to provide alternative implementations
with different time-accuracy ratio or to parse different file formats.

Finally, "strategies" are local, parser-specific plans how to parse
the input text. They are an informal in-parser concept and do not have
corresponding Crystal classes.

## Parser: "Basic"

HTML parser "Basic" (defined in `src/app/parser/html/basic.cr`) is
implemented to test the assumption that a performant and sufficiently
accurate parser could be written using a text-based approach with
only minimal HTML awareness (trivial HTML support, no exact boundary
identification, no tag nesting, etc.).

It performs fast, non-regex searches within the input text to
identify offsets of interest. The data within the offsets is then extracted
into substrings for further processing. This further, targeted processing may
then use more expensive functionality such as regex matching, etc.

The parser's low-level functionality consists of the following primitives:

- `find_range`: given HTML tag name, finds the offsets of the text enclosed
in it. Also supports an Iterator to yield tags in succession.

- `find_open` / `find_closed`: finds only the begin or end offset of a
HTML tag.

### Basic strategies

The parser currently implements three strategies:

- Searching for date among the HTML meta tags
- Searching for date within JSON in script type="application/json" blocks
- Searching for the first date found in the page (as a final fallback)

They are by no means complete and both the quality and quantity of
parsing methods could grow significantly. They produce initial results
and help evaluate the general approach.

### Substrings and byte copying

As mentioned,
after offsets are determined, the contained bytes are usually extracted
into substrings on which further processing is then performed.

This is convenient because one does not have to use offsets everywhere,
especially since most Crystal functions do not support specifying the end offset.

Calling `string[range]` to
extract a substring implicitly creates a copy of the bytes contained in
the range. This is accepted for now, as the alternatives do not
result in a particularly clean implementation.

### Regex matching and date extraction

Regex matching is convenient to carry out the final step of identifying
the exact offsets and date formats.

Once offset and date formats are determined using any method (but mostly
regex matching is used to determine the exact position of dates and
to extract their values), the dates are
converted into `Time` instances. When dates consists of numbers which
can be sent as arguments to `Time#new`, that approach is used. When the
values as not numeric (such as "January"), the format is determined as
well and Times are instantiated using `Time#parse(string, format)`.
As a last step, those `Time` instances are displayed in HTML results
using format '%Y-%m-%d'.

Important to mention is that `Time.parse` requires specifying the
input format. The format thus needs to be pre-determined using
custom code as part of the parser. Ruby's `Date::parse`,
`Time::parse`, and `DateTime::parse` methods, which do implement
autodetection, could potentially be ported to Crystal.

### Possible performance improvements

General performance improvements are mentioned in *README.md*, while
this section is about the algorithm specifically.

The current implementation uses a couple LibC functions directly, although
this was an experiment and is not crucial for the current performance level
because other, more expensive operations are also used (such as implicit string
copying whenever `String#[]` is called.)

Performance improvements could be achieved by eliminating instantiation
of extra String objects as well byte copying that would happen as part of it.
This is not an easy task for a couple of reasons:

Each String object consists of a header `{TYPE_ID : Int32, bytesize : Int32,
size : Int32}` immediately followed by bytes. So it is not possible to
create multiple strings pointing to the same bytes. (For reference, invoking
`string.as(Int32*)` gives access to the three header fields, and invoking
`string.to_unsafe` gives access to the bytes.)

Furthermore, String class can't be subclassed. One could create a separate
class whose `to_unsafe` would point to the string's bytes and this would
save time on copying the bytes (a time which grows linearly with the length
of string and could be significant), but it would not save time on time for
object creation (nor would solve all problems).

The absolute best performance could be achieved by working on only one /
original copy of the string. This would be possible if the implementation
adhered to the following principles:

- In internal functions, always report search results as byte offsets {Begin,End} and/or pointers
into the bytes (conversion between the two is easy - just pointer arithmetics)
- Use only functions which support specifying the starting offset (string + B). This includes all
LibC functions accepting `char*` as one can manually adjust the byte pointer to the desired offset (e.g.
`LibC.something( string.to_unsafe + offset, ... )`
- For functions which do not support specifying the end offset, work around it
by temporarily modifying the string's bytesize (header field 2) and optionally
also setting the the corresponding end byte to null-char (for LibC functions)
- After the content between offsets {B,E} is processed, restore the bytesize and nulled character. This
is easy to implement using blocks (e.g. `def process(...) set_state; yield; restore_state`)
