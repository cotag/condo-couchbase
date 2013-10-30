module Condo
    module Backend
        
        #
        # The following data needs to be stored in any backend
        # => provider_namespace (for handling multiple upload controllers, defaults to global)
        # => provider_name        (amazon, rackspace, google, azure etc)
        # => provider_location    (US West (Oregon) Region, Asia Pacific (Singapore) Region etc)
        # => user_id            (the identifier for the current user as a string)
        # => file_name            (the original upload file name)
        # => file_size            (the file size as indicated by the client)
        # => file_id            (some sort of identifying hash provided by the client)
        # => bucket_name        (the name of the users bucket)
        # => object_key            (the path to the object in the bucket)
        # => object_options        (custom options that were applied to this object - public/private etc)
        # => resumable_id        (the id of the chunked upload)
        # => resumable            (true if a resumable upload - must be set)
        # => date_created        (the date the upload was started)
        #
        # => Each backend should have an ID that uniquely identifies an entry - id or upload_id
        #
        #
        #
        # Backends should inherit this class, set themselves as the backend and define the following:
        #
        # Class Methods:
        # => check_exists        ({user_id, upload_id})                            returns nil or an entry where all fields match
        #         check_exists    ({user_id, file_name, file_size, file_id})        so same logic for this
        # => add_entry ({user_id, file_name, file_size, file_id, provider_name, provider_location, bucket_name, object_key})
        #
        #            
        #
        # Instance Methods:
        # => update_entry ({upload_id, resumable_id})
        # => remove_entry (upload_id)
        #
        class Couchbase < ::Couchbase::Model
            include ::CouchHelp::IdGenerator

            attribute :created_at,      default: lambda { Time.now.to_i }
            attribute :user_id, :file_name, :file_size, :file_id, 
                :provider_namespace, :provider_name, :provider_location, :bucket_name,
                :object_key, :object_options_raw, :resumable_id, :resumable, :file_path



            def object_options=(hash)
                self.object_options_raw = hash.to_json
            end

            def object_options
                JSON.parse(self.object_options_raw)
            end
            
            
            #
            # Checks for an exact match in the database given a set of parameters
            #
            def self.check_exists(params)
                if params[:upload_id].nil?
                    params[:upload_id] = self.bucket.get("uplding-#{params[:user_id]}-#{params[:file_id]}-#{params[:file_name]}-#{params[:file_size]}", quiet: true)
                end
                upload = self.find_by_id(params[:upload_id])
                if upload.present? && upload.user_id != params[:user_id].to_s
                    upload = nil
                end
                upload
            end
            
            #
            # Adds a new upload entry into the database
            #
            def self.add_entry(params)
                model = self.new(params)
                model.object_options = params[:object_options]
                model.save!
                self.bucket.set("uplding-#{params[:user_id]}-#{params[:file_id]}-#{params[:file_name]}-#{params[:file_size]}", model.id)
                model
            end
            
            #
            # Updates self with the passed in parameters
            #
            def update_entry(params)
                self.update_attributes(params)
                result = self.save
                raise ActiveResource::ResourceInvalid if result == false
                self
            end
            
            #
            # Deletes references to the upload
            #
            def remove_entry
                self.delete
                self.class.bucket.delete("uplding-#{self.user_id}-#{self.file_id}-#{self.file_name}-#{self.file_size}")
            end
            
            
            #
            # Attribute accessors to comply with the backend spec
            #
            def upload_id
                self.id
            end
            
            def date_created
                @date_created ||= Time.at(self.created_at)
            end
            
        end
    end
end
