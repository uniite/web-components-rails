module WebComponentsRails::AssetTagHelper
  # Based on stylesheet_link_tag_with_print in Sprockets
  def html_import_tag(*sources)
    options = sources.extract_options!.stringify_keys
    path_options = options.extract!('protocol').symbolize_keys
    debug_mode = options['debug'] != false && request_debug_assets?

    sources.map do |source|
      # Optional; provided by better_errors
      if respond_to?(:check_errors_for)
        check_errors_for(source, type: :html)
      end
      # In debug mode, include each html asset separately (if we can find the asset)
      if debug_mode
        asset = lookup_html_debug_asset(source)
        asset.to_a.map do |a|
          _html_import_tag(path_to_asset(a.logical_path, path_options.merge(debug: true)))
        end
      # In production mode, or when we can't find the asset, fall back to a single tag
      else
        _html_import_tag(source, path_options)
      end
    end.flatten.uniq.join("\n").html_safe
  end


  private

    def _html_import_tag(source, path_options = {})
      tag_options = {
        rel: 'import',
        href: path_to_asset(source, path_options.merge(extname: '.html', type: :html))
      }
      tag(:link, tag_options)
    end

    def lookup_html_debug_asset(path)
      path = path_with_extname(path, type: :html)

      resolve_asset do |resolver|
        resolver.find_debug_asset path
      end
    end
    
end
