require 'haml'
class WebComponentsRails::Railtie < Rails::Railtie
  # Register our asset tag helpers
  initializer 'web_components.asset_tag_helper' do
    ActionView::Base.module_eval do
      include WebComponentsRails::AssetTagHelper
    end
    Rails.application.assets.context_class.class_eval do
      include WebComponentsRails::AssetTagHelper
    end
  end

  # Allows HAML templates to be used with asset pipeline
  initializer 'web_components.sprockets', after: 'sprockets.environment', group: :all do |app|
    app.assets.register_mime_type 'text/html', extensions: ['.html', '.haml']
    app.assets.register_preprocessor 'text/html', Sprockets::DirectiveProcessor
    app.assets.register_preprocessor 'text/html', WebComponentsRails::HTMLImportProcessor
    app.assets.register_engine '.haml', WebComponentsRails::HamlTemplate
    app.assets.register_bundle_processor 'text/html', ::Sprockets::Bundle
  end
end

