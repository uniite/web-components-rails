require_relative '../lib/web_components_rails'

describe 'Integration with Rails' do
  let(:js_path) { File.join(@tmp_asset_path, 'test.js') }
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
  end

  context 'given HTML with referenced JavaScript' do
    let(:component_name) { 'component-with-js' }
    let(:js_path) { File.join(@tmp_asset_path, 'test.js') }
    before do
      open(js_path, 'w') do |f|
        f.write('var x = 1;')
      end
      compile_asset(component_name)
    end

    it 'inlines the JavaScript where the script tag was' do
      expect(File.read(output_path)).to eq(
        "<p>Component 1</p>\n\n" +
        "<script original-src=\"test.js\">\n" +
        "var x = 1;\n" +
        "</script>\n" +
        "<div>My Component</div>\n"
      )
    end

    it 'will update the HTML when the script changes' do
      expect(File.read(output_path)).to include('var x = 1;')

      # Need to make sure the mtime is different from the original test.js
      # (Sprockets modification time checks only work with second resolution)
      sleep 1
      open(js_path, 'w') do |f|
        f.write('var y = 2;')
      end
      compile_asset(component_name)
      expect(File.read(output_path)).to include('var y = 2;')
    end
  end
end
