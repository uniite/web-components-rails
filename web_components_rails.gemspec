# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'web_components_rails/version'

Gem::Specification.new do |spec|
  spec.name          = 'web_components_rails'
  spec.version       = WebComponentsRails::VERSION
  spec.authors       = ['Jon Botelho']
  spec.email         = ['jon@jbotelho.com']
  spec.summary       = %q{Web components utils for rails}
  spec.description   = spec.summary

  spec.files         = ['lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # Used for HTML5 parsing of polymer components (see lib/web_components/html_import_processor.rb)
  # The normal Nokogiri/libxml HTML parser does not fully support Polymer HTML syntax
  # (such as <div class$="{{foo}}"></div>)
  spec.add_dependency 'nokogumbo', '>= 1.4.5'
  spec.add_dependency 'railties', '>= 4.0.0'
  spec.add_dependency 'sprockets', '>= 3.0.0'
end
