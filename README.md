# web_components_rails
Ruby gem for using web components in Rails applications.

[![Build Status](https://travis-ci.org/uniite/web-components-rails.svg)](https://travis-ci.org/uniite/web-components-rails) 

## Usage
1. Include the gem in your Gemfile:
```ruby
gem 'web_components_rails'
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

## Building

After adding new features or fixes, please update the version in version.rb, and then tag the repo appropriately:

```
git tag -a -m 'Added foo' 1.1.0
git push --tags
```

To release the gem (internally), use `rake build`, and push the gem with stickler.
