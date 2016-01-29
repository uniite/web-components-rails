class WebComponentsRails::HamlTemplate < Tilt::HamlTemplate
  def prepare
    @options = @options.merge(format: :html5)
    super
  end
end
