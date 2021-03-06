Pod::Spec.new do |s|
	s.name             = "BCDataStream"
	s.version          = "0.1.0"
	s.summary          = "A pair of utility classes for decoding and encoding binary data streams."
	s.homepage         = "https://github.com/sethk/BCDataStream"
	s.license          = 'BSD'
	s.author           = { "Seth Kingsley" => "sethk@meowfishies.com" }
	s.source           = { :git => "https://github.com/sethk/BCDataStream.git", :tag => s.version.to_s }

	s.ios.deployment_target = '5.0'
	s.osx.deployment_target = '10.6'
	s.requires_arc = true
	s.compiler_flags = '-fobjc-arc-exceptions'

	s.default_subspec = 'Core'

	s.subspec 'Core' do |ss|
		ss.source_files = 'Classes'
		ss.public_header_files = 'Classes/BN{Abstract,Input,Output}DataStream.h'
		ss.frameworks = 'Foundation'
	end

	s.subspec 'Tests' do |ss|
		ss.source_files = 'Tests'
		ss.frameworks = 'XCTest'
		ss.dependency 'BCDataStream/Core'
	end
end
