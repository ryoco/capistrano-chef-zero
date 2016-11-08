# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "capistrano-chef-zero"
  spec.version       = "0.1.0"
  spec.summary       = %q{chef-zero with capstrano}
  spec.license       = "MIT"

  spec.authors       = ["ryoco"]
  spec.email         = ["kato.ryoco@gmail.com"]
  spec.homepage      = "https://github.com/ryoco/capistrano-chef-zero"

  spec.require_paths = ["lib"]
  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.add_development_dependency 'capistrano', '~> 3.6.1'
  spec.add_development_dependency 'sshkit', '~> 1.11.4'

  # spec.add_development_dependency "bundler", "~> 1.13"
  # spec.add_development_dependency "rake", "~> 10.0"
end
