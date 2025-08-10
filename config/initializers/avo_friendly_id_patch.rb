# Patch Avo's ActionsController to handle FriendlyId slugs in bulk actions
Rails.application.config.after_initialize do
  if defined?(Avo::ActionsController)
    Avo::ActionsController.class_eval do
      # Store the original set_query method if it exists
      if instance_methods(false).include?(:set_query)
        alias_method :original_set_query, :set_query
      end
      
      private
      
      # Override set_query to handle slug-based bulk actions
      def set_query
        Rails.logger.debug "[Avo Patch] set_query called with params: #{params[:fields].inspect}" if Rails.env.development?
        
        # Handle bulk actions with FriendlyId slugs
        if params[:fields] && params[:fields][:avo_resource_ids].present?
          ids = params[:fields][:avo_resource_ids]
          
          Rails.logger.debug "[Avo Patch] Processing bulk action with IDs: #{ids.inspect}" if Rails.env.development?
          
          # Ensure resource is set
          if @resource.nil? && params[:resource_name].present?
            resource_class = "Avo::Resources::#{params[:resource_name].singularize.camelize}".safe_constantize
            @resource = resource_class.new if resource_class
            Rails.logger.debug "[Avo Patch] Created resource: #{@resource.class}" if Rails.env.development? && @resource
          end
          
          if @resource && @resource.class.respond_to?(:find_records)
            @query = @resource.class.find_records(ids, params: params)
            Rails.logger.debug "[Avo Patch] Found #{@query.size} records using find_records" if Rails.env.development?
            return
          elsif @resource && @resource.class.respond_to?(:find_record)
            # Fall back to finding each record individually
            id_list = ids.is_a?(String) ? ids.split(',').map(&:strip) : ids
            @query = id_list.map do |id|
              @resource.class.find_record(id, params: params) rescue nil
            end.compact
            Rails.logger.debug "[Avo Patch] Found #{@query.size} records via individual lookups" if Rails.env.development?
            return
          end
        end
        
        # Fall back to original implementation if available
        if respond_to?(:original_set_query, true)
          original_set_query
        else
          # Default implementation
          @query = @record || (@resource.model_class.none if @resource)
        end
      end
    end
    
    # Patch the handle action to ensure query is properly set
    Avo::ActionsController.class_eval do
      if instance_methods(false).include?(:handle)
        alias_method :original_handle, :handle
      end
      
      def handle
        # Ensure query is set before handling
        set_query unless @query
        
        Rails.logger.debug "[Avo Patch] handle called with @query: #{@query.class} (#{@query.respond_to?(:size) ? @query.size : 'N/A'} items)" if Rails.env.development?
        
        if respond_to?(:original_handle, true)
          original_handle
        else
          # Default behavior
          head :ok
        end
      end
    end
  end
end