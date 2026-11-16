ENV['APP_ENV'] = 'test'

require 'bundler/setup'
require 'minitest/autorun'
require 'rack/mock'
require_relative '../main'

# Faraday's test adapter returns a body without the streaming callback used by
# the real Net::HTTP adapter. Deliver the fixture bytes through that callback.
class StreamFixtureBody < Faraday::Middleware
  def on_complete(env)
    env.request.on_data&.call(env.body, env.body.bytesize, env)
  end
end

# Replace HTTP transport only; extraction and rendering use the real library.
class MetaInspector::HttpSession
  class << self
    attr_accessor :image_requests
  end

  def build(url, image: false, **)
    self.class.image_requests << url if image
    Faraday.new(url: url) do |connection|
      connection.headers.merge!(@headers || {})
      connection.use StreamFixtureBody
      connection.adapter :test do |stub|
        stub.get('/rich') { [200, { 'content-type' => 'text/html; charset=utf-8', 'x-demo' => 'fixture' }, File.read(File.join(__dir__, 'fixtures/rich.html'))] }
        stub.get('/empty') { [200, { 'content-type' => 'text/html' }, '<html><head></head><body></body></html>'] }
        stub.get('/agent') do |env|
          title = Rack::Utils.escape_html(env.request_headers['User-Agent'].to_s)
          [200, { 'content-type' => 'text/html' }, "<html><head><title>#{title}</title></head></html>"]
        end
        stub.get('/many') do
          images = (1..10).map { |index| %(<img src="/image#{index}.png">) }.join
          [200, { 'content-type' => 'text/html' }, "<html><body>#{images}</body></html>"]
        end
        stub.get('/latin') do
          html = '<html><head><meta charset="ISO-8859-1"><title>Café</title></head><body>Café</body></html>'.encode('ISO-8859-1')
          [200, { 'content-type' => 'text/html; charset=ISO-8859-1' }, html]
        end
        stub.get('/binary') do
          html = '<html><head><meta charset="utf-8"><title>Wikipedia · 日本語</title></head><body>Español · Русский</body></html>'.b
          [200, { 'content-type' => 'text/html' }, html]
        end
        stub.get('/fail') { raise Faraday::ConnectionFailed, 'Cannot reach <example>' }
        stub.get(%r{\A/(?:cover|image\d+)\.png\z}) do
          png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l1sAAAAASUVORK5CYII=')
          [200, { 'content-type' => 'image/png', 'content-length' => png.bytesize.to_s }, png]
        end
      end
    end
  end
end

class DemoTest < Minitest::Test
  def request(path, params = {}, headers = {})
    MetaInspector::HttpSession.image_requests = []
    Rack::MockRequest.new(Sinatra::Application).get(path, { params: params }.merge(headers))
  end

  def document(response, status: 200)
    assert_equal status, response.status, response.body[0, 500]
    Nokogiri::HTML(response.body)
  end

  def test_home_explains_features_and_has_an_accessible_form
    doc = document(request('/'))
    assert doc.at_css('script[src*="@tailwindcss/browser@4"]')
    assert doc.at_css('form[action="/scrape"] input[name="url"][required]')
    assert doc.at_css('label[for="url"]')
    %w[Metadata Images Links Headings Feeds Iframes HTTP JSON].each do |feature|
      assert_includes doc.text, feature
    end
  end

  def test_rich_page_exposes_feature_groups_and_real_extracted_values
    doc = document(request('/scrape', url: 'https://example.test/rich?utm_source=demo'))
    %w[overview social images links headings feeds resources iframes response data].each do |id|
      assert doc.at_css("section##{id}"), "Missing #{id} section"
      assert doc.at_css("nav a[href='##{id}']"), "Missing #{id} navigation"
    end
    %w[Internal External Non-HTTP].each { |label| assert_includes doc.at_css('#links').text, label }
    assert_includes doc.at_css('#headings').text, 'Smallest heading'
    assert_includes doc.at_css('#feeds').text, 'application/atom+xml'
    assert_includes doc.at_css('#resources').text, 'https://example.test/style.css'
    assert_includes doc.at_css('#iframes').text, 'https://example.test/embed'
    assert_includes doc.at_css('#response').text, 'fixture'
    assert_includes doc.at_css('#response').text, 'https://example.test/rich'
    assert_includes doc.at_css('#images').text, '640 × 480'
    assert_equal 'https://example.test/rich?utm_source=demo', doc.at_css('input[name="url"]')['value']
    payload = JSON.parse(doc.at_css('#json-export').text)
    assert_equal 'Social title', payload['best_title']
    assert_equal ['one', 'two'], payload.dig('meta_tags', 'name', 'keywords')
  end

  def test_scraped_html_and_unsafe_schemes_stay_inert
    doc = document(request('/scrape', url: 'https://example.test/rich'))
    assert_includes doc.text, '<script>alert(1)</script>'
    assert_empty doc.css('script').select { |script| script.text.include?('alert(1)') }
    assert_empty doc.css('[onerror]')
    assert_empty doc.css('iframe')
    assert_empty doc.css('a[href], img[src]').select { |node| (node['href'] || node['src']).match?(/\A(?:javascript|data):/i) }
    assert_includes doc.at_css('#links').text, 'javascript:alert(1)'
  end

  def test_missing_data_has_empty_states_and_no_broken_preview
    doc = document(request('/scrape', url: 'https://example.test/empty'))
    assert_includes doc.at_css('#images').text, 'No images'
    assert_includes doc.at_css('#feeds').text, 'No feeds'
    assert_includes doc.at_css('#iframes').text, 'No iframes'
    assert_empty doc.css('img[src=""]')
    assert_equal 10, doc.css('main section[id]').length
  end

  def test_error_page_escapes_the_message_and_allows_retry
    doc = document(request('/scrape', url: 'https://example.test/fail'), status: 500)
    assert_includes doc.text, 'Cannot reach <example>'
    assert_empty doc.css('example')
    assert_equal 'https://example.test/fail', doc.at_css('input[name="url"]')['value']
  end

  def test_missing_or_blank_url_redirects_home
    ['/scrape', '/scrape?url=', '/scrape?url=%20%20'].each do |path|
      response = request(path)
      assert_equal 302, response.status
      assert_equal 'http://example.org/', response.headers['location']
    end
  end

  def test_non_utf8_source_is_displayed_without_breaking_the_result_page
    doc = document(request('/scrape', url: 'https://example.test/latin'))
    assert_includes doc.at_css('#overview').text, 'Café'
    source = doc.css('#data details').find { |node| node.at_css('summary').text == 'Original HTML source' }
    assert_includes source.text, 'Café'
  end

  def test_binary_utf8_source_keeps_its_characters_when_rendered
    doc = document(request('/scrape', url: 'https://example.test/binary'))
    source = doc.css('#data details').find { |node| node.at_css('summary').text == 'Original HTML source' }
    assert_includes source.text, 'Wikipedia · 日本語'
    assert_includes source.text, 'Español · Русский'
    refute_includes source.text, "\uFFFD"
  end

  def test_optional_image_details_include_type_size_and_validity
    doc = document(request('/scrape', url: 'https://example.test/rich', image_details: '1'))
    details = JSON.parse(doc.at_css('#image-details').text)
    image = details.find { |item| item['url'] == 'https://example.test/cover.png' }
    assert_equal 'png', image['type']
    assert_operator image['file_size'], :>, 0
    metadata = JSON.parse(doc.at_css('#image-validity').text)
    assert_equal true, metadata.find { |item| item['url'] == image['url'] }['valid']
    assert doc.at_css('input[name="image_details"][checked]')
  end

  def test_image_lookups_are_opt_in_and_share_a_six_request_limit
    document(request('/scrape', url: 'https://example.test/many'))
    assert_empty MetaInspector::HttpSession.image_requests

    doc = document(request('/scrape', url: 'https://example.test/many', image_details: '1'))
    assert_equal 6, MetaInspector::HttpSession.image_requests.size
    metadata = JSON.parse(doc.at_css('#image-validity').text)
    assert_equal 10, metadata.size
    assert_equal 6, metadata.count { |image| image['valid'] == true }
    assert_equal 4, metadata.count { |image| image['valid'].nil? }
  end

  def test_custom_user_agent_is_sent_to_the_page_and_preserved_in_the_form
    agent = 'DemoBot/1.0 (+https://example.test/bot)'
    doc = document(request('/scrape', { url: 'https://example.test/agent', user_agent: agent }, { 'HTTP_USER_AGENT' => 'VisitorBrowser/2.0' }))
    assert_equal agent, JSON.parse(doc.at_css('#json-export').text)['best_title']
    assert_equal agent, doc.at_css('input[name="user_agent"]')['value']
    assert_includes doc.at_css('#response').text, agent
  end

  def test_user_agent_defaults_on_home_and_for_missing_or_blank_values
    home = document(request('/'))
    assert home.at_css('label[for="user-agent"]')
    default_agent = home.at_css('input[name="user_agent"]')['value']
    refute_empty default_agent

    [{}, { user_agent: '' }, { user_agent: '   ' }].each do |params|
      doc = document(request('/scrape', { url: 'https://example.test/agent' }.merge(params)))
      assert_equal default_agent, JSON.parse(doc.at_css('#json-export').text)['best_title']
    end
  end

  def test_custom_user_agent_remains_escaped_and_available_after_a_request_error
    agent = 'DemoBot/1.0 "<script>alert(1)</script>'
    doc = document(request('/scrape', url: 'https://example.test/fail', user_agent: agent), status: 500)
    assert_equal agent, doc.at_css('input[name="user_agent"]')['value']
    assert_empty doc.css('script').select { |script| script.text.include?('alert(1)') }
  end

  def test_home_prefills_the_visitors_browser_user_agent
    browser_agent = 'VisitorBrowser/2.0 (Mobile)'
    doc = document(request('/', {}, { 'HTTP_USER_AGENT' => browser_agent }))
    assert_equal browser_agent, doc.at_css('input[name="user_agent"]')['value']
  end

  def test_missing_or_blank_user_agent_uses_the_visitors_browser_for_scraping
    browser_agent = 'VisitorBrowser/2.0 (Mobile)'
    [{}, { user_agent: '' }, { user_agent: '  ' }].each do |params|
      doc = document(request('/scrape', { url: 'https://example.test/agent' }.merge(params), { 'HTTP_USER_AGENT' => browser_agent }))
      assert_equal browser_agent, JSON.parse(doc.at_css('#json-export').text)['best_title']
      assert_equal browser_agent, doc.at_css('input[name="user_agent"]')['value']
    end
  end
end
