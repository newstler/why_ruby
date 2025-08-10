# Patch Avo controllers to handle FriendlyId slugs properly
Rails.application.config.after_initialize do
  # Patch ActionsController for bulk actions
  if defined?(Avo::ActionsController)
    Avo::ActionsController.class_eval do
      # Store original methods - check both public and private
      if private_method_defined?(:set_query)
        alias_method :original_set_query, :set_query
      end
      
      if method_defined?(:set_record) || private_method_defined?(:set_record)
        alias_method :original_set_record, :set_record
      end
      
      private
      
      # Override set_query to handle FriendlyId slugs
      def set_query
        Rails.logger.info "[Avo Patch] set_query called" if Rails.env.development?
        
        # Handle bulk actions with multiple IDs
        if params[:fields] && params[:fields][:avo_resource_ids].present?
          ids = params[:fields][:avo_resource_ids]
          
          Rails.logger.info "[Avo Patch] Bulk action with IDs: #{ids}" if Rails.env.development?
          
          # Ensure we have a resource
          if @resource.nil? && params[:resource_name].present?
            resource_class = "Avo::Resources::#{params[:resource_name].singularize.camelize}".safe_constantize
            @resource = resource_class.new if resource_class
          end
          
          # Find all records using our custom finder
          if @resource && @resource.class.respond_to?(:find_records)
            @query = @resource.class.find_records(ids, params: params)
            Rails.logger.info "[Avo Patch] Found #{@query.size} records using find_records" if Rails.env.development?
          else
            # Fallback to finding individually
            id_list = ids.is_a?(String) ? ids.split(',').map(&:strip) : ids
            @query = id_list.map do |id|
              begin
                if @resource && @resource.class.respond_to?(:find_record)
                  @resource.class.find_record(id, params: params)
                elsif @resource && @resource.model_class
                  @resource.model_class.friendly.find(id)
                end
              rescue ActiveRecord::RecordNotFound
                Rails.logger.info "[Avo Patch] Record not found for ID: #{id}" if Rails.env.development?
                nil
              end
            end.compact
            Rails.logger.info "[Avo Patch] Found #{@query.size} records via individual lookup" if Rails.env.development?
          end
          
          # CRITICAL: Ensure @query is always an array for bulk actions
          @query = Array(@query) unless @query.is_a?(Array)
          
          Rails.logger.info "[Avo Patch] Final @query: #{@query.class} with #{@query.size} items" if Rails.env.development?
        elsif respond_to?(:original_set_query, true)
          # Not a bulk action, use original behavior
          original_set_query
        else
          # Fallback if no original method
          @query = @record || (@resource&.model_class&.none)
        end
      rescue => e
        Rails.logger.error "[Avo Patch] Error in set_query: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        @query = []
      end
      
      # Override set_record to handle our modified @query
      def set_record
        Rails.logger.info "[Avo Patch] set_record called" if Rails.env.development?
        
        if params[:fields] && params[:fields][:avo_resource_ids].present? && !params[:id].present?
          # For bulk actions, don't try to set a single record
          # @query should already be an array from our set_query
          Rails.logger.info "[Avo Patch] Bulk action detected, skipping single record logic" if Rails.env.development?
          @record = nil
        elsif respond_to?(:original_set_record, true)
          # Use original behavior for non-bulk actions
          original_set_record
        elsif params[:id].present?
          # Fallback: find single record
          if @resource && @resource.class.respond_to?(:find_record)
            @record = @resource.class.find_record(params[:id], params: params)
          elsif @resource && @resource.model_class
            @record = @resource.model_class.find(params[:id])
          end
        elsif @query.respond_to?(:size) && @query.size == 1
          @record = @query.first
        else
          @record = nil
        end
      rescue => e
        Rails.logger.error "[Avo Patch] Error in set_record: #{e.message}"
        @record = nil
      end
    end
  end
end