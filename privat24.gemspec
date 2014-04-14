Gem::Specification.new do |s|
  s.name        = 'privat24'
  s.version     = '0.0.1'
  s.date        = '2014-04-14'
  s.summary     = "Ruby wrapper for Privat24 API"
  s.description = "Allows to transfer funds between privat24 users"
  s.authors     = ["Artem Harmaty"]
  s.email       = 'harmaty@gmail.com'
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/harmaty/privat24'
  s.add_dependency "activesupport"
end
