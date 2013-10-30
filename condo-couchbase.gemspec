$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "condo_couchbase/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "condo-couchbase"
  s.version     = CondoCouchbase::VERSION
  s.authors     = ["Stephen von Takach"]
  s.email       = ["steve@cotag.me"]
  s.homepage    = "http://cotag.me/"
  s.summary     = "Couchbase backend for the Condo project."
  s.description = "Provides database storage utilising Couchbase."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["LGPL3-LICENSE", "Rakefile", "README.textile"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 4.0.0"
  s.add_dependency "condo"
  s.add_dependency "couchbase-model"
end
