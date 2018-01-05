require 'securerandom'

# Processes web component HTML files that contains imports
# See also:
#   https://github.com/rails/sprockets/blob/master/UPGRADING.md
#   https://github.com/rails/sprockets/blob/3.x/lib/sprockets/directive_processor.rb
class WebComponentsRails::HTMLImportProcessor

  VERSION = '10'
  XML_SAVE_OPTIONS = {
    save_with: ::Nokogiri::XML::Node::SaveOptions::DEFAULT_XML | ::Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS
  }

  # URI attributes are determined by using the attributes list at https://html.spec.whatwg.org/#attributes-3
  # and looking for attributes that specify "Valid URL" as their values
  URI_ATTRIBUTES = %w(
    action
    cite
    data
    formaction
    href
    itemid
    manifest
    ping
    poster
    src
  ).freeze

  # URI attributes are determined by using the attributes list at https://html.spec.whatwg.org/#attributes-3
  # and looking for attributes that specify "Boolean attribute" as their values
  BOOLEAN_ATTRIBUTES = %w(
    allowfullscreen
    allowpaymentrequest
    allowusermedia
    async
    autofocus
    autoplay
    checked
    controls
    default
    defer
    disabled
    formnovalidate
    hidden
    ismap
    itemscope
    loop
    multiple
    muted
    nomodule
    novalidate
    open
    playsinline
    readonly
    required
    reversed
    selected
  ).freeze

  def self.instance
    @instance ||= new
  end

  def self.call(input)
    instance.call(input)
  end

  def self.cache_key
    instance.cache_key
  end

  def self.doc_to_html(doc)
    doc_html = doc.to_html(encoding: 'UTF-8')

    uri_regex = Regexp.union(URI_ATTRIBUTES)
    square_brackets_regex = Regexp.new("(#{uri_regex})=\"%5B%5B(.+?)%5D%5D\"", 'i')
    curly_braces_regex = Regexp.new("(#{uri_regex})=\"%7B%7B(.+?)%7D%7D\"", 'i')

    selectors = (URI_ATTRIBUTES + BOOLEAN_ATTRIBUTES).map { |attribute| "*[#{attribute}]"}
    doc.css(selectors.join(',')).each do |node|
      # Nokogiri only writes out valid HTML so this outputs some nodes that would not be valid HTML
      # (e.g. nodes with boolean attributes that have values, or nodes that have unescaped URI attributes)
      # as both HTML and XML, and uses swap out the HTML for XML in the complete document HTML.
      pattern = node.to_html
      replacement = node.to_xml(XML_SAVE_OPTIONS)

      # Nokogiri/Nokogumbo are hard-coded to URI-escape certain attributes (src, href, action, and a[name]),
      # so we have to put in placeholders, and fix the values in the HTML string output afterwards
      # This doesn't work so well with framework-specific syntax (eg. <foo src="{{bar}}">)
      replacement.gsub!(square_brackets_regex, '\1="[[\2]]"')
      replacement.gsub!(curly_braces_regex, '\1="{{\2}}"')

      doc_html.gsub!(pattern, replacement)
    end

    doc_html
  end


  attr_reader :cache_key

  def initialize(options = {})
    @cache_key = [self.class.name, VERSION, options].freeze
  end

  def call(input)
    # Sprockets::Environment for looking up assets, etc.
    @environment = input[:environment]
    @context = @environment.context_class.new(input)
    @data = input[:data]
    @filename = input[:filename]
    @dirname = File.dirname(@filename)

    @data, paths = process_imports(@data, @dirname)
    paths.each do |path|
      @context.require_asset(path)
    end

    @context.metadata.merge(data: @data)
  end


  protected

    def process_imports(html, base_dir)
      doc = Nokogiri::HTML5.fragment(html)

      # Process HTML and CSS imports
      dependencies = doc.css('link').map do |link|
        href = link.attributes['href'].value
        path = href_to_asset_path(href, base_dir)
        rel = link.attributes['rel'].value
        type_attr = link.attributes['type']
        # The rel determines what type it is by default, but an explicit type will always supercede this
        if type_attr
          type = type_attr.value.downcase
        elsif rel == 'import'
          type = 'html'
        elsif rel == 'stylesheet'
          type = 'css'
        # Unknown link type; ignore
        else
          type = nil
        end

        case type
          # HTML needs to be required as an external dependency, with the import removed
          when 'html', 'text/html'
            link.remove
            href_to_asset_path(href, base_dir)
          # CSS needs to be inlined
          when 'css', 'text/css'
            asset = @environment.find_asset(path, accept: 'text/css')
            # Replace it inline with a style node containing the referenced CSS
            if asset
              style = Nokogiri::XML::Element.new('style', doc)
              style['original-href'] = href
              style.content = "\n" + asset.source
              link.replace(style)
              # Let sprockets know we're dependent on this asset, so that the HTML gets re-compiled when the CSS changes
              @context.depend_on_asset(path)
            end
            nil
          # Ignore unknown types
          else
            nil
        end
      end.compact

      # Script/JS imports should just have their src rewritten to work with sprockets
      # (because they could repeat a lot, and we can't mark non-HTML files as dependencies)
      doc.css('script[src]').map do |script|
        src = script.attributes['src'].value
        if src.present?
          # Some references may try to be relative to the bower_components root,
          # which is already in the asset pipeline search path; fix those
          # (eg. from 'web_components/lib-a/foo.html', <script src='../lib-b/bar.js'> -> 'lib-b/bar.js')
          path = href_to_asset_path(src, base_dir)
          asset = @environment.find_asset(path, accept: 'application/javascript')
          # Replace it with a script tag containing the referenced JS inline
          if asset
            new_script = Nokogiri::XML::Element.new('script', doc)
            new_script['original-src'] = src
            new_script.content = "\n" + asset.source
            script.replace(new_script)
            # Let sprockets know we're dependent on this asset, so that the HTML gets re-compiled when the script changes
            @context.depend_on_asset(path)
          end
        end
      end

      new_html = self.class.doc_to_html(doc)

      [new_html, dependencies]
    end

    def href_to_asset_path(href, base_dir)
      abs_path = File.expand_path(File.join(base_dir, href))
      # If it is relative to the current dir, we should be able to find it easily
      if File.exist?(abs_path)
        abs_path
      # Otherwise, just return it as a relative path, and hope sprockets can find it in an asset dir
      else
        # Sometimes we prefix with /assets/ to make the HTML work in the browser without asset-pipeline.
        # We don't need this when using require with sprockets.
        href.sub(%r{^/assets/}, '')
      end
    end

end
