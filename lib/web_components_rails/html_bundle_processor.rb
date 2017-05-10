require 'securerandom'
require 'uglifier'

# Compresses HTML bundles
class WebComponentsRails::HTMLBundleProcessor

  VERSION = '1'

  def self.instance
    @instance ||= new
  end

  def self.call(input)
    instance.call(input)
  end

  def self.cache_key
    instance.cache_key
  end

  attr_reader :cache_key

  def initialize(options = {})
    @cache_key = [self.class.name, VERSION, options, WebComponentsRails.optimize_scripts].freeze
  end

  def call(input)
    # Sprockets::Environment for looking up assets, etc.
    @environment = input[:environment]
    @context = @environment.context_class.new(input)
    @data = input[:data]

    @data = process_bundle(@data)

    @context.metadata.merge(data: @data)
  end


  protected

    def process_bundle(html)
      doc = Nokogiri::HTML5.fragment(html)
      doc = process_css(doc)
      doc = process_scripts(doc)
      doc = process_comments(doc)
      html = WebComponentsRails::HTMLImportProcessor.doc_to_html(doc)
      if !!WebComponentsRails.optimize_scripts
        html.gsub(/\n+/, "\n").gsub(/\n\s+/, "\n")
      else
        html
      end
    end

    def process_comments doc
      return doc unless !!WebComponentsRails.remove_html_comments
      doc.xpath('//comment()').remove
      doc
    end

    def process_scripts doc
      # Don't do anything if we have optimization off
      return doc unless !!WebComponentsRails.optimize_scripts

      combined_js = ''

      doc.css('script:not([src])').map do |script|
        combined_js << script.content
        combined_js << "\n"
        script.remove
      end

      combined_script_tag = optimized_script_tag(doc, combined_js)
      
      body = doc.at_css('html body')
      if body
        body << combined_script_tag
      else
        doc << combined_script_tag
      end

      doc
    end

    def process_css doc

      return doc unless !!WebComponentsRails.optimize_css

      doc.css('style').map do |style|
        # Assume uglifier is fine with defaults for minification
        minified_css = css_compressor.compress(style.content)
        style.inner_html = minified_css
      end

      doc
    end

    def optimized_script_tag(doc, raw_js)
        combined_script_tag = Nokogiri::XML::Element.new('script', doc)

        # Assume uglifier is fine with defaults for minification
        minified_js = Uglifier.compile(raw_js)

        # Data-URI encode the JS (helps a lot in browsers like IE)
        inlined_js = 'data:text/javascript;base64,'
        inlined_js << Base64.strict_encode64(minified_js).gsub('=', '%3D')
        combined_script_tag['src'] = inlined_js

        combined_script_tag
    end

    def css_compressor
      @yui_compressor ||= YUI::CssCompressor.new
    end

end
