require 'digest/sha2'

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
        class Couchbase < ::CouchbaseOrm::Base
            design_document :co_upld
            before_create :generate_id


            attribute :created_at, default: proc { Time.now.to_i }
            attribute :user_id, :file_name, :file_size, :file_id, 
                :provider_namespace, :provider_name, :provider_location, :bucket_name,
                :object_key, :object_options, :resumable_id, :resumable, :file_path,
                :part_list, :part_data


            # Checks for an exact match in the database given a set of parameters
           def self.check_exists(params)
                upload_id = params.delete(:upload_id)
                upload_id ||= "upld-#{params[:user_id]}-#{Digest::SHA256.hexdigest("#{params[:file_id]}-#{params[:file_name]}-#{params[:file_size]}")}"
                self.find_by_id(upload_id)
            end

            # Adds a new upload entry into the database
            def self.add_entry(params)
                model = self.new
                [:user_id, :file_name, :file_size, :file_id, 
                :provider_namespace, :provider_name, :provider_location, :bucket_name,
                :object_key, :object_options, :resumable_id, :resumable, :file_path,
                :part_list, :part_data].each { |key| model.__send__("#{key}=", params[key]) if params[key] }
                model.save!
                model
            end

            # Return a list of Uploads that were last updated before a particular time
            index_view :user_id

            def self.older_than(time)
                old_upload = time.to_i
                uploads = []
                self.all_uploads.each do |upload|
                    uploads << upload if upload.created_at < old_upload
                end
                uploads
            end

            def self.all_uploads
                self.by_user_id
            end


            # Updates self with the passed in parameters
            def update_entry(params)
                self.update_attributes(params)
                result = self.save
                raise ActiveResource::ResourceInvalid if result == false
                self
            end

            # Deletes references to the upload
            def remove_entry
                self.delete
            end

            # Attribute accessors to comply with the backend spec
            def upload_id
                self.id
            end
            
            def date_created
                @date_created ||= Time.at(self.created_at)
            end

            # Provide a clean up function that uses the condo strata to delete itself
            # NOTE:: this won't work with completely dynamic providers so is really just here
            #  as a helper if you have pre-defined storage providers
            def cleanup
                options = {}
                options[:namespace] = self.provider_namespace if self.provider_namespace
                options[:location] = self.provider_location if self.provider_location
                residence = ::Condo::Configuration.get_residence(self.provider_name, options)

                if residence
                    residence.destroy(self)
                    self.remove_entry
                else
                    raise NotImplementedError, 'unable to find static residence'
                end
            end


            protected


            def generate_id
                self.id = "upld-#{self.user_id}-#{Digest::SHA256.hexdigest("#{self.file_id}-#{self.file_name}-#{self.file_size}")}"
            end
        end
    end
end
