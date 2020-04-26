# Parsing and extraction

## Introduction

The first task in designing the parsing strategy was to determine the
performance of various functions that would probably always be used,
regardless of specifics.

A series of files in the benchmarks/ directory implements those tests.
Many tests also check for performance of C-level functions, even though
those are not used in the implementation.

### Processors, Downloaders, and Parsers

The application structure is clean, complete and implemented as a possible
mini model of a larger, real implementation.

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
with different time-accuracy ratio or parse different file formats.

Finally, "strategies" are local, parser-specific plans how to parse
the input text. They are an informal in-parser concept and do not have
corresponding Crystal classes.

If the parser does not find the published date (at all, or quickly
enough, or with high-enough confidence score), the model would allow for
calling further (slower/better?) parsers.
Alternatively/additionally,
the system could keep score of parser success on particular domains and/or
its subfolders and dynamically adjust the order or choice of parsers
invoked. Only one parser exists in the current implementation.

## Parser: "Basic"

HTML parser "Basic" (defined in `src/app/parser/html/basic.cr`) is
implemented to test the assumption that a performant and sufficiently
accurate parser could be written using a text-based approach with
only minimal HTML awareness (trivial HTML support, no exact boundary
identification, no tag nesting, etc.).

It performs non-regex searches within the input text to
identify offsets of interest. The data within the offsets is then extracted
into substrings for further processing. This targeted processing may
use more expensive (Crystal-level) functionality
such as regex matching, etc.

The parser's low-level functionality consists of the following primitives:

- `find_range`: given HTML tag name, finds the text enclosed in it.
Also supports an Iterator to yield tags in succession.

- `find_open` / `find_closed`: finds only the begin or end offset of a
HTML tag.

- `find_enclosing`: given an offset in the body, finds the Range of the
HTML tag enclosing it.

### Substrings and byte copying

As mentioned,
after offsets are determined, the contained bytes are usually extracted
into substrings on which further processing is performed.

This is convenient because one does not have to litter the code with
begin and end offsets, especially since most Crystal functions
do not support specifying the end offset.

Calling `string[range]` to
extract a substring implicitly creates a copy of the bytes contained in
the range. This is accepted for now, as the alternatives do not
result in particularly clean implementation (for example, it could
involve modifying string objects' headers and/or inserting null-bytes
in it).

### Regex matching and date extraction

Regex matching is convenient to carry out the final step of identifying
the exact offsets and date formats.

Once offset and date format are determined using any method, standard
`Time.parse` is called to produce Time instances representing the dates.
As a last step, dates are displayed in HTML results using format
'%Y-%m-%d'.

Passing dates as strings without Time objects could be marginally faster,
but much less flexible, especially in the context of a larger processing
system.

Important to mention is that `Time.parse` requires specifying the
input format. The format thus  needs to be pre-determined using
custom code as part of the parser. Or, potentially Ruby's `Date::parse`,
`Time::parse`, and `DateTime::parse` methods, which do implement
autodetection, could be ported to Crystal.
