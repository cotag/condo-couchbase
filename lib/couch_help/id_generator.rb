#
# This disables the built in generator
# => Faster then running validations twice
#
module Couchbase
    class Model
        class UUID
            def initialize(*args)
                
            end
            
            def next(*args)
                nil
            end
        end
    end
end


#
# This is our id generator, runs in the before save call back
#
module CouchHelp
    
    # incr, decr, append, prepend == atomic
    # 
    module IdGenerator
        
        B65 = Radix::Base.new(Radix::BASE::B62 + ['-', '_', '~'])
        B10 = Radix::Base.new(10)
        
        def self.included(base)
            base.class_eval do
                
                @@class_id_generator = proc do |name, cluster_id, overflow, count|
                    id = Radix.convert([overflow, cluster_id].join.to_i, B10, B65) + Radix.convert(count, B10, B65)
                    "#{name}-#{id}"
                end
                
                #
                # Best case we have 18446744073709551615 * 18446744073709551615 model entries for each database cluster
                #  and we can always change the cluster id if this limit is reached
                #
                define_model_callbacks :save, :create
                before_save :generate_id
                before_create :generate_id
                
                def generate_id
                    if self.id.nil?
                        name = "#{self.class.name.underscore.gsub!(/\/|_/, '-')}"      # The included classes name
                        cluster = ENV['COUCHBASE_CLUSTER'] || 1     # Cluster ID number
                        
                        
                        #
                        # Generate the id (incrementing values as required)
                        #
                        overflow = self.class.bucket.get("#{name}:#{cluster}:overflow", :quiet => true) # Don't error
                        count = self.class.bucket.incr("#{name}:#{cluster}:count", :create => true)     # This classes current id count
                        if count == 0 || overflow.nil?
                            overflow ||= 0
                            overflow += 1
                            self.class.bucket.set("#{name}:#{cluster}:overflow", overflow)      # We shouldn't need to worry about concurrency here
                        end
                        
                        self.id = @@class_id_generator.call(name, cluster, overflow, count)
                        
                        
                        #
                        # So an existing id would only be present if:
                        # => something crashed before incrementing the overflow
                        # => this is another request occurring before the overflow is incremented
                        #
                        # Basically only the overflow should be able to cause issues, we'll increment the count just to be sure
                        # One would hope this code only ever runs under high load if an overflow occurs
                        #
                        while self.class.bucket.get(self.id, :quiet => true).present?
                            self.class.bucket.set("#{name}:#{cluster}:overflow", overflow + 1)      # Set in-case we are here due to a crash (concurrency is not an issue)
                            count = self.class.bucket.incr("#{name}:#{cluster}:count")              # Increment just in case (attempt to avoid infinite loops)
                            
                            self.id = @@class_id_generator.call(name, cluster, overflow + 1, count)             # Generate the new id
                        end
                    end
                end
                
                #
                # Override the default hashing function
                #
                def self.set_class_id_generator(&block)
                    @@class_id_generator = block
                end
                
                
            end # END:: class_eval
        end # END:: included
        
    end # END:: IdGenerator
end