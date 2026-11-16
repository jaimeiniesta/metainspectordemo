# MetaInspector demo

This is just a demo for the [MetaInspector](https://github.com/jaimeiniesta/metainspector) ruby gem, that helps you in scraping web pages.

## Setup

Requires Ruby 3.3 or newer.

```
bundle install
```

## Launch

```
bundle exec rackup
```

And go to http://localhost:9292

## Demo features

Inspect a public HTML page to explore metadata and social previews, images and
favicons, classified links, H1–H6 headings, feeds, page resources, iframe sources,
URL tracking and HTTP responses. The raw-data section includes all metadata
formats, the complete JSON data hash (with copy/download controls) and HTML source.

Tailwind CSS 4 and daisyUI 5 load from a CDN, without a frontend build step.
Image dimensions use HTML attributes by default; enable **Fetch image details**
for up to six remote lookups of dimensions, file type, file size and validity.
Unknown or unchecked metadata remains explicitly marked.

Set **User Agent** to send a custom `User-Agent` header when fetching the page
and its images. It is prefilled from the visitor's browser and is preserved in
results and errors; leaving it blank uses the browser's User Agent. If the browser
does not send one, the demo uses MetaInspector's identification. The selected
value also appears in **URL & HTTP response**.

## Tests

```sh
bundle exec ruby test/demo_test.rb
```

Integration tests use real MetaInspector parsing with local HTML fixtures and
replace HTTP transport, so they do not require external network access.
