require 'condo'
require 'condo-couchbase/engine'
require 'condo/backend/couchbase'

#::Condo::Application.backend = Condo::Backend::Couchbase
silence_warnings { ::Condo.const_set(:Store, ::Condo::Backend::Couchbase) }
