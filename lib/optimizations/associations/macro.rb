module Scrooge
  module Optimizations 
    module Associations
      module Macro
        
        class << self
          
          # Inject into ActiveRecord
          #
          def install!
            if scrooge_installable?
              ActiveRecord::Base.send( :extend,  SingletonMethods )
              ActiveRecord::Base.send( :include, InstanceMethods )              
            end  
          end
      
          private
          
            def scrooge_installable?
              !ActiveRecord::Base.included_modules.include?( InstanceMethods )
            end
         
        end
        
      end
      
      module SingletonMethods
      
        @@preloadable_associations = {}
        FindAssociatedRegex = /preload_associations|preload_one_association/
      
        def self.extended( base )
          eigen = class << base; self; end
          eigen.instance_eval do
            # Let :scrooge_callsite be a valid find option
            #
            valid_find_options = eigen::VALID_FIND_OPTIONS
            remove_const(:VALID_FIND_OPTIONS)
            const_set( :VALID_FIND_OPTIONS, valid_find_options << :scrooge_callsite )
          end
          eigen.alias_method_chain :find, :scrooge
          eigen.alias_method_chain :find_every, :scrooge
        end
      
        # Let .find setup callsite information and preloading.
        #
        def find_with_scrooge(*args)
          options = args.extract_options!
          validate_find_options(options)
          set_readonly_option!(options)
           
          options = scrooge_optimize_preloading!( options )

          case args.first
            when :first then find_initial(options)
            when :last  then find_last(options)
            when :all   then find_every(options)
            else             find_from_ids(args, options)
          end
        end
      
        # Override find_ever to pass along the callsite signature
        #
        def find_every_with_scrooge(options)
          include_associations = merge_includes(scope(:find, :include), options[:include])

          if include_associations.any? && references_eager_loaded_tables?(options)
            records = find_with_associations(options)
          else
            records = find_by_sql(construct_finder_sql(options), options[:scrooge_callsite]) #scrooged_records_for_find_every( options ) 
            if include_associations.any?
              preload_associations(records, include_associations)
            end
          end

          records.each { |record| record.readonly! } if options[:readonly]

          records
        end      
        
        # Let's not preload polymorphic associations or collections
        #      
        def preloadable_associations
          @@preloadable_associations[self.name] ||= reflect_on_all_associations.reject{|a| a.options[:polymorphic] || a.macro == :has_many }.map{|a| a.name }
        end              
        
        private
          
          def scrooge_optimize_preloading!( options )
            options[:scrooge_callsite] = callsite_signature( (_caller = caller), options.except(:conditions, :limit, :offset) ) 
            if should_optimize_preloading?( _caller )
              options[:include] = scrooge_callsite(options[:scrooge_callsite]).preload( options[:include] ) 
            end

            if should_augment_select_options?( options )
              options[:select] = augment_given_select_option( options )
            end
            options
          end
          
          # Should a given :select option be optimized ?
          #
          def should_augment_select_options?( options )
            options[:select] && scrooge_callsite(options[:scrooge_callsite]).augmented_columns?
          end
          
          # Should preloading be optimized ( ignore recursion via association_preload.rb ) ?
          #
          def should_optimize_preloading?( call_tree )
            call_tree.grep( FindAssociatedRegex ).empty?
          end
          
          # Ensure a scrooged instance for custom :select options
          #
          def scrooged_records_for_find_every( options )
            if options[:select]
              find_by_sql_with_scrooge(construct_finder_sql(options.merge!( :select => augment_given_select_option( options ) ) ), options[:scrooge_callsite])
            else
              find_by_sql(construct_finder_sql(options), options[:scrooge_callsite])
            end    
          end
          
          def augment_given_select_option( options )
            "#{options[:select]}, #{scrooge_select_sql( scrooge_callsite( options[:scrooge_callsite] ).columns )}"
          end  
              
      end
      
      module InstanceMethods
                
        # Association getter with Scrooge support
        #
        def association_instance_get(name)
          association = instance_variable_get("@#{name}")
          if association.respond_to?(:loaded?)
            scrooge_seen_association!( name )
            association
          end
        end

        # Association setter with Scrooge support
        #
        def association_instance_set(name, association)
          scrooge_seen_association!( name )
          instance_variable_set("@#{name}", association)
        end
        
        private
        
          # Register an association with Scrooge
          #
          def scrooge_seen_association!( association )
            if scrooged? && !scrooge_seen_association?( association )
              @attributes.scrooge_associations << association
              self.class.scrooge_callsite( @attributes.callsite_signature ).association!( association ) 
            end
          end        
        
          # Has this association already been flagged for the callsite ? 
          #
          def scrooge_seen_association?( association )
            @attributes.scrooge_associations.include?( association )
          end
        
      end
      
    end
  end
end      