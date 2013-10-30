require 'condo'
require 'condo_couchbase/engine'
require 'couch_help/id_generator'
require 'condo/backend/couchbase'

#::Condo::Application.backend = Condo::Backend::Couchbase
silence_warnings { ::Condo.const_set(:Store, Condo::Backend::Couchbase) }
