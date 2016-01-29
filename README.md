# web_components_rails
Ruby gem for using web components in Rails applications.

## Usage
1. Include the gem in your Gemfile, using our internal RubyGems server as the source:
```ruby
# Most internal projects should have this source already
source 'http://rubygems.dev.bloomberg.com/' do
    gem 'web_components_rails'
end
```
2. Add an HTML file to your project (can be just HTML or a Polymer component):
```html
<!-- app/assets/javascripts/my_component.html -->
<h1>Hello</h1>
```
3. Include a web component in one of your views:
```erb
<%= html_import_tag 'my_component' %>
```
