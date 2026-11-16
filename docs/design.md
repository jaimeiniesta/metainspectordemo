# MetaInspector demo refresh

Refresh the existing Sinatra/ERB app in place. Keep `/`, `/scrape`, the `url`
query parameter, the English interface, and the existing GitHub links.

Use Tailwind CSS 4's browser CDN and daisyUI 5's CDN stylesheet, with a light
theme, restrained blue accent, system typography, generous spacing, and modest
rounded corners. The form stays prominent on every page. Results use a sticky
section index on desktop and a wrapping index on mobile.

Use 18px body text, labels and navigation, with at least 16px for code and
captions. Secondary text uses solid dark slate rather than reduced opacity.
Give fields stronger borders, 56px input/button heights and roomier data rows.

The shared form exposes an editable User Agent. Send it through MetaInspector's
request headers for the page and image lookups, retain it on results and errors,
and show the effective value in URL & HTTP response. Prefill it from the visitor's
request User-Agent; missing/blank overrides use that same browser header, falling
back to MetaInspector's identification only when the visitor sends no header.

Show real MetaInspector 5.21 data: best and original text fields, language and
charset, social tags and a link preview, suggested/best/largest images and image
dimensions, file types/sizes and validity, classified links and raw hrefs,
H1–H6, feeds, head links, stylesheets,
canonicals, iframe attributes/sources, URL normalization/tracking, HTTP response,
all meta tag formats, the complete hash and HTML source. Keep large collections
scrollable or collapsible and provide explicit empty states.

Escape all scraped strings. Only HTTP(S) URLs become remote links/images; other
schemes stay readable as text. Never embed scraped HTML or iframe content.
Keep optional image lookups bounded to six requests shared across all image
methods. Normalize displayed text to UTF-8, including the original HTML source.

Implementation sequence:

1. Add integration coverage using real MetaInspector parsing of local fixtures,
   with only HTTP transport replaced. Cover rich pages, missing data, unsafe
   markup/URLs, form persistence, redirects, and extraction failures.
2. Replace legacy rendering helpers with escaped reusable ERB partials. Prepare
   image selections once per request and expose all supported feature groups.
3. Replace the layout, home, result, and error views; add progressive loading
   feedback and JSON download/copy controls. Basic browsing works without JS.
4. Run the integration suite, Ruby syntax and diff checks, then inspect desktop
   and mobile rendering in a browser when available.
