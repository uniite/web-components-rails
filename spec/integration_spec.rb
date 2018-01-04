require_relative '../lib/web_components_rails'

describe 'Integration with Rails' do
  let(:output_path) { File.join(@tmp_path, 'compiled.html') }

  before(:all) do
    @asset_path = File.join(File.dirname(__FILE__), 'fixtures')
    @tmp_path = File.join(File.dirname(__FILE__), '..', 'tmp')
    @tmp_asset_path = File.join(@tmp_path, 'assets')
    @cache_path = File.join(@tmp_path, 'cache')
    @output_path = File.join(@tmp_path, 'compiled.html')
    @log_path = File.join(@tmp_path, 'log')

    require 'rails'
    @rails_app = Class.new(Rails::Application)
    @rails_app.config.eager_load = false
    @rails_app.config.active_support.deprecation = :stderr
    @rails_app.config.assets.enabled = true
    @rails_app.config.assets.cache_store = [ :file_store, @cache_path ]
    @rails_app.config.assets.paths = [ @asset_path, @tmp_asset_path ]
    @rails_app.paths['log'] = File.join(@log_path, 'test.log')
    @rails_app.initialize!

  end
  before do
    FileUtils.mkdir_p(@tmp_asset_path)
  end
  after do
    [@cache_path, @log_path, output_path, @tmp_asset_path].each do |path|
      FileUtils.rm_rf(path)
    end
  end

  def compile_asset(name)
    FileUtils.rm(output_path) if File.exist?(output_path)
    @rails_app.assets[name].write_to(output_path)
  end


  it 'can process simple HTML assets' do
    compile_asset('simple1')
    expect(File.read(output_path)).to eq("<p>Component 1</p>\n")
  end

  it 'can process complex HTML assets' do
    compile_asset('complex1')
    expect(File.read(output_path)).to eq(
      "<a href=\"{{url}}\">Click</a>\n" +
      "<select name=\"text\"><option value=\"value1\" selected=\"[[selected]]\">Value 1</option></select>\n"
    )
  end

  context 'given HTML with imports' do
    # Dependencies look like:
    #   bundle -> [simple1, simple2]
    #   simple1 -> []
    #   simple2 -> [simple1, simple3]
    #   simple3 -> []
    # Solution: simple1, simple3, simple 2
    it 'concatenates the files in dependency order' do
      compile_asset('bundle')
      expect(File.read(output_path).gsub(/\n{2,}/, "\n")).to \
        eq("<p>Component 1</p>\n<p>Component 3</p>\n<p>Component 2</p>\n")
    end

    context 'with multiple scripts' do
      it 'keeps the scripts as-is' do
        compile_asset('bundle_js')
        expect(File.read(output_path).gsub(/\n{2,}/, "\n")).to \
          eq("<component>\n<script>\nvar x = 1;\n</script>\n</component>\n<script>\nvar y = 2;\n</script>\n")
      end

      context 'with WebComponentsRails.optimize_scripts = true' do
        before do
          WebComponentsRails.optimize_scripts = true
        end
        after do
          WebComponentsRails.optimize_scripts = nil
        end

        it 'bundles, minifies, and inlines the scripts' do
          compile_asset('bundle_js')
          expect(File.read(output_path).gsub(/\n{2,}/, "\n")).to \
            eq("<component>\n</component>\n<script src=\"data:text/javascript;base64,dmFyIHg9MSx5PTI7\"></script>")
        end
      end
    end
  end

  context 'given HTML with referenced JavaScript' do
    let(:component_name) { 'component-with-js' }
    let(:js_path) { File.join(@tmp_asset_path, 'test.js') }
    let(:original_js) { 'var x = 1;' }
    let(:new_js) { 'var x = 2;' }
    before do
      open(js_path, 'w') do |f|
        f.write(original_js)
      end
      compile_asset(component_name)
    end

    it 'inlines the JavaScript where the script tag was' do
      expect(File.read(output_path)).to eq(
        "<p>Component 1</p>\n\n" +
        "<script original-src=\"test.js\">\n" +
        "#{original_js}\n" +
        "</script>\n" +
        "<div>My Component</div>\n"
      )
    end

    it 'will update the HTML when the script changes' do
      expect(File.read(output_path)).to include(original_js)

      # Need to make sure the mtime is different from the original version
      # (Sprockets modification time checks only work with second resolution)
      sleep 1
      open(js_path, 'w') do |f|
        f.write(new_js)
      end
      compile_asset(component_name)
      expect(File.read(output_path)).to include(new_js)
    end
  end

  context 'given HTML with referenced CSS' do
    let(:component_name) { 'component-with-css' }
    let(:css_path) { File.join(@tmp_asset_path, 'test.css') }
    let(:original_css) { 'p { color: gray; }' }
    let(:new_css) { 'p { color: orange; }' }
    before do
      open(css_path, 'w') do |f|
        f.write(original_css)
      end
      compile_asset(component_name)
    end

    it 'inlines the CSS where the link tag was' do
      expect(File.read(output_path)).to eq(
        "<dom-module id=\"my-component\">\n" +
        "    <template>\n" +
        "        <style original-href=\"test.css\">\n#{original_css}\n</style>\n" +
        "    </template>\n" +
        "</dom-module>\n"
      )
    end

    it 'will update the HTML when the CSS changes' do
      expect(File.read(output_path)).to include(original_css)

      # Need to make sure the mtime is different from the original version
      # (Sprockets modification time checks only work with second resolution)
      sleep 1
      open(css_path, 'w') do |f|
        f.write(new_css)
      end
      compile_asset(component_name)
      expect(File.read(output_path)).to include(new_css)
    end
  end
end
