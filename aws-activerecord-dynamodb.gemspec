# frozen_string_literal: true

version = File.read(File.expand_path('VERSION', __dir__)).strip

Gem::Specification.new do |spec|
  spec.name         = 'aws-activerecord-dynamodb'
  spec.version      = version
  spec.author       = 'Amazon Web Services'
  spec.email        = ['aws-dr-rubygems@amazon.com']
  spec.summary      = 'ActiveRecord integration with DynamoDB'
  spec.description  = 'Amazon DynamoDB for ActiveRecord'
  spec.homepage     = 'https://github.com/aws/aws-activerecord-dynamodb-ruby'
  spec.license      = 'Apache-2.0'
  spec.files        = Dir['LICENSE', 'CHANGELOG.md', 'VERSION', 'lib/**/*']

  spec.add_dependency('aws-record', '~> 2')

  spec.add_dependency('railties', '>= 7.1.0')

  spec.required_ruby_version = '>= 2.7'
end