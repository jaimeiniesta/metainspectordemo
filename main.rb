require 'sinatra'
require 'sinatra/reloader'
require 'metainspector'
require 'json'

set :show_exceptions, :after_handler

helpers do
  def user_agent
    supplied = params[:user_agent].to_s.strip
    return supplied unless supplied.empty?

    browser_agent = request.user_agent.to_s.strip
    return browser_agent unless browser_agent.empty?

    "MetaInspector/#{MetaInspector::VERSION} (+https://github.com/jaimeiniesta/metainspector)"
  end

  def h(value)
    text = value.to_s
    source_encoding = text.encoding == Encoding::BINARY ? Encoding::UTF_8 : text.encoding
    Rack::Utils.escape_html(text.encode(Encoding::UTF_8, source_encoding, invalid: :replace, undef: :replace))
  end

  def web_url?(value)
    uri = Addressable::URI.parse(value.to_s)
    %w[http https].include?(uri.scheme&.downcase) && !uri.host.to_s.empty?
  rescue Addressable::URI::InvalidURIError, ArgumentError
    false
  end

  def external_link(value, label = value)
    return h(label) unless web_url?(value)

    %(<a href="#{h(value)}" target="_blank" rel="noopener noreferrer" class="underline decoration-base-content/25 underline-offset-4 hover:decoration-current [overflow-wrap:anywhere]">#{h(label)}</a>)
  end

  def fields(rows)
    erb :_fields, layout: false, locals: { rows: rows }
  end

  def url_list(items, empty: 'No links found.')
    erb :_url_list, layout: false, locals: { items: items, empty: empty }
  end

  def json_block(value, id: nil)
    erb :_json, layout: false, locals: { value: value, id: id }
  end

  def section_heading(title, description, method_name)
    erb :_section_heading, layout: false, locals: { title: title, description: description, method_name: method_name }
  end
end

get '/' do
  erb :home
end

get '/scrape' do
  @submitted_url = params[:url].to_s.strip
  if !@submitted_url.empty?
    @page = MetaInspector.new(@submitted_url,
                              :connection_timeout => 5, :read_timeout => 5,
                              :headers => { 'User-Agent' => user_agent, 'Accept-Encoding' => 'identity' },
                              :faraday_options => { :ssl => { :verify => false } },
                              :download_images => params[:image_details] == '1',
                              :fetch_all_image_meta => params[:image_details] == '1',
                              :max_image_downloads => 6,
                              :allow_non_html_content => false)
    @image_sizes = @page.images.with_size
    @image_details = @page.images.with_details
    @image_validity = @page.images.with_metadata
    @best_image = @page.images.best
    @largest_image = @page.images.largest
    @page_data = @page.to_hash
    erb :scrape
  else
    redirect "/"
  end
end

error MetaInspector::Error do
  @exception_title = env['sinatra.error'].class.to_s
  @exception_msg   = env['sinatra.error'].message
  erb :error
end
