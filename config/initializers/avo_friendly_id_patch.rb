# Patch Avo controllers to handle FriendlyId slugs properly
Rails.application.config.after_initialize do
  # Patch ActionsController for bulk actions and single-record actions
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
            # Whitelist of allowed resource names to prevent arbitrary code execution
            allowed_resources = %w[categories comments posts reports tags users]
            resource_name = params[:resource_name].to_s.downcase.singularize

            if allowed_resources.include?(resource_name)
              resource_class = "Avo::Resources::#{resource_name.camelize}".safe_constantize
              @resource = resource_class.new if resource_class
            else
              Rails.logger.warn "[Avo Patch] Attempted to access invalid resource: #{params[:resource_name]}"
            end
          end

          # Find all records using our custom finder
          if @resource && @resource.class.respond_to?(:find_records)
            @query = @resource.class.find_records(ids, params: params)
            Rails.logger.info "[Avo Patch] Found #{@query.size} records using find_records" if Rails.env.development?
          else
            # Fallback to finding individually
            id_list = ids.is_a?(String) ? ids.split(",").map(&:strip) : ids
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

      # Override set_record to handle our modified @query AND single-record actions with slugs
      def set_record
        Rails.logger.info "[Avo Patch] set_record called with params[:id]=#{params[:id].inspect}" if Rails.env.development?

        if params[:fields] && params[:fields][:avo_resource_ids].present? && !params[:id].present?
          # For bulk actions, don't try to set a single record
          # @query should already be an array from our set_query
          Rails.logger.info "[Avo Patch] Bulk action detected, skipping single record logic" if Rails.env.development?
          @record = nil
        elsif params[:id].present?
          # For single record actions, ALWAYS use our custom find_record
          # This handles both regular navigation and single-record actions
          Rails.logger.info "[Avo Patch] Single record action, using custom find_record" if Rails.env.development?

          if @resource && @resource.class.respond_to?(:find_record)
            @record = @resource.class.find_record(params[:id], params: params)
            Rails.logger.info "[Avo Patch] Found record: #{@record.class}##{@record.id}" if Rails.env.development? && @record
          elsif @resource && @resource.model_class
            # Fallback to model with friendly finders
            @record = @resource.model_class.find(params[:id])
          else
            # Call original if no resource available
            original_set_record if respond_to?(:original_set_record, true)
          end
        elsif @query.respond_to?(:size) && @query.size == 1
          # ActionsController's special case: single item in query
          @record = @query.first
          Rails.logger.info "[Avo Patch] Set record from single-item query" if Rails.env.development?
        else
          @record = nil
        end
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "[Avo Patch] Record not found: #{e.message}"
        flash[:error] = e.message
        @record = nil
      rescue => e
        Rails.logger.error "[Avo Patch] Error in set_record: #{e.message}"
        @record = nil
      end
    end
  end
end
