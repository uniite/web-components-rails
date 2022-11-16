require 'active_support'
require 'nokogiri'
require 'sprockets'

module WebComponentsRails

  mattr_accessor :optimize_scripts
  
end

require 'web_components_rails/asset_tag_helper'
require 'web_components_rails/html_bundle_processor'
require 'web_components_rails/html_import_processor'
require 'web_components_rails/railtie'
require 'web_components_rails/version'
