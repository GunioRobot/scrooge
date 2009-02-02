module Scrooge
  module Framework
    class Rails < Base
      
      # Look for RAILS_ROOT, ActiveSupport && ActionController constants.
      
      signature do
        defined?(RAILS_ROOT)
      end
      
      signature do
        Object.const_defined?( "ActiveSupport" )
      end

      signature do
        Object.const_defined?( "ActionController" )
      end
      
      def environment
        ::Rails.env.to_s
      end
      
      def root
        ::Rails.root
      end
      
      def tmp
        File.join( ::Rails.root, 'tmp' )
      end
      
      def config
        File.join( ::Rails.root, 'config' )
      end
      
      def logger
        ::Rails.logger
      end
      
      def resource( env )
        GUARD.synchronize do
          # TODO: Wonky practice to piggy back on this current Edge / 2.3 hack
          request = env['action_controller.rescue.request']
          Thread.scrooge_resource.controller = request.path_parameters['controller']
          Thread.scrooge_resource.action = request.path_parameters['action']
          Thread.scrooge_resource.method = request.method
          Thread.scrooge_resource.format = request.format.to_s        
        end
      end      
      
      def read_cache( key )
        ::Rails.cache.read( key )
      end      
      
      def write_cache( key, value )
        ::Rails.cache.write( key, value )
      end
      
      def middleware
        ::Rails.configuration.middleware
      end    
      
      # Push the Tracking middle ware into the first slot. 
      #      
      def install_tracking_middleware
        GUARD.synchronize do
          middleware.insert( 0, Scrooge::Middleware::Tracker )        
        end
      end
      
      # Install per Resource scoping middleware.
      #
      def install_scope_middleware( tracker )
        GUARD.synchronize do
          tracker.resources.each do |resource|
            resource.middleware.each do |resource_middleware|
              middleware.use( resource_middleware )
            end
          end
        end  
      end
      
      def initialized( &block )
        ::Rails.configuration.after_initialize( &block )
      end
      
    end
  end
end