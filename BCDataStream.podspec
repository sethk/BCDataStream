Pod::Spec.new do |s|
	s.name             = "BCDataStream"
	s.version          = "0.1.0"
	s.summary          = "A pair of utility classes for decoding and encoding binary data streams."
	s.homepage         = "http://EXAMPLE/NAME"
	s.license          = 'BSD'
	s.author           = { "Seth Kingsley" => "sethk@meowfishies.com" }
	s.source           = { :git => "http://EXAMPLE/NAME.git", :tag => s.version.to_s }

	s.ios.deployment_target = '5.0'
	s.osx.deployment_target = '10.6'
	s.requires_arc = true
	s.compiler_flags = '-fobjc-arc-exceptions'

	s.default_subspec = 'Core'

	s.subspec 'Core' do |ss|
		ss.source_files = 'Classes'
		s.public_header_files = 'Classes/BN{Abstract,Input,Output}DataStream.h'
		s.frameworks = 'Foundation'
	end
end
