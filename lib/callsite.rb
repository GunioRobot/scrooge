module Scrooge
  class Callsite
    
    # Represents a Callsite and is a container for any columns and 
    # associations ( coming soon ) referenced at the callsite.
    #
    
    Mtx = Mutex.new
    
    attr_accessor :klass,
                  :signature,
                  :columns,
                  :associations
    
    def initialize( klass, signature )
      @klass = klass
      @signature = signature
      @default_columns = setup_columns 
      @columns = @default_columns.dup
      @associations = setup_associations
    end
    
    # Flag a column as seen
    #
    def column!( column )
      Mtx.synchronize do 
        @columns << column
      end
    end
    
    # Has any columns other than the primary key or possible inheritance column been generated
    #
    def augmented_columns?
      !augmented_columns.empty?
    end
    
    # Return all augmented ( excluding primary key or inheritance column ) columns
    #
    def augmented_columns
      @columns - @default_columns
    end
    
    # Diff known associations with given includes
    #
    def preload( includes )
      # Ignore nested includes for the time being
      #
      if includes.is_a?(Hash)
        includes
      else  
        @associations.merge( Array(includes) ).to_a
      end
    end  
    
    # Flag an association as seen
    #
    def association!( association )
      Mtx.synchronize do
        @associations << association if preloadable_association?( association )
      end
    end
    
    def inspect
      "<##{@klass.name} :select => '#{@klass.scrooge_select_sql( @columns )}', :include => [#{associations_for_inspect}]>"
    end
    
    private
    
      def associations_for_inspect
        @associations.map{|a| ":#{a.to_s}" }.join(', ')
      end
    
      # Only register associations that isn't polymorphic or a collection
      #
      def preloadable_association?( association )
        @klass.preloadable_associations.include?( association.to_sym )
      end
    
      # Is the table a container for STI models ?
      # 
      def inheritable?
        @klass.column_names.include?( inheritance_column )
      end
    
      # Ensure that at least the primary key and optionally the inheritance
      # column ( for STI ) is set. 
      #
      def setup_columns
        if inheritable?
          Set.new([primary_key, inheritance_column])
        else
          primary_key.blank? ? Set.new : Set.new([primary_key])
        end    
      end
    
      # Stubbed for future use
      #
      def setup_associations
        Set.new
      end
    
      # Memoize a string representation of the inheritance column
      #
      def inheritance_column
        @inheritance_column ||= @klass.inheritance_column.to_s
      end

      # Memoize a string representation of the primary
      #    
      def primary_key
        @primary_key ||= @klass.primary_key.to_s
      end    
    
  end
end