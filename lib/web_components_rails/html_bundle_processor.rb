require 'securerandom'
require 'terser'

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
      # Don't do anything if we have optimization off
      return html unless !!WebComponentsRails.optimize_scripts

      doc = Nokogiri::HTML5.fragment(html)

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

      WebComponentsRails::HTMLImportProcessor.doc_to_html(doc)
    end

    def optimized_script_tag(doc, raw_js)
        combined_script_tag = Nokogiri::XML::Element.new('script', doc)

        # Assume terser is fine with defaults for minification
        minified_js = Terser.compile(raw_js)

        # Data-URI encode the JS (helps a lot in browsers like IE)
        inlined_js = 'data:text/javascript;base64,'
        inlined_js << Base64.strict_encode64(minified_js).gsub('=', '%3D')
        combined_script_tag['src'] = inlined_js

        combined_script_tag
    end

end
