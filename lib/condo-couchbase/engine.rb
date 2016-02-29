module CondoCouchbase
    class Engine < ::Rails::Engine
        engine_name :condo_couchbase

        config.after_initialize do |app|
            model_conf = Couchbase::Model::Configuration
            temp = model_conf.design_documents_paths

            path = File.expand_path(File.join(File.dirname(__FILE__), '../condo/backend'))
            model_conf.design_documents_paths = [path]
            
            ::Condo::Backend::Couchbase.ensure_design_document!

            model_conf.design_documents_paths = temp
        end
    end
end
