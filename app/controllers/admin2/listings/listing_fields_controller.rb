module Admin2::Listings
  class ListingFieldsController < Admin2::AdminBaseController

    include CustomFieldTypes

    before_action :field_type_is_valid, only: %i[new create]
    before_action :find_custom_field, except: %i[index new create order]

    def index
      @custom_fields = @current_community.custom_fields
      shapes = @current_community.shapes
      @price_in_use = shapes.any? { |s| s[:price_enabled] }
    end

    def new
      if params[:field_type].present?
        @custom_field = params[:field_type].constantize.new
        if params[:field_type] == 'CheckboxField'
          @min_option_count = 1
          @custom_field.options = [CustomFieldOption.new(sort_priority: 1)]
        else
          @min_option_count = 2
          @custom_field.options = [CustomFieldOption.new(sort_priority: 1),
                                   CustomFieldOption.new(sort_priority: 2)]
        end
      end
      render layout: false
    end

    def edit
      @min_option_count = params[:field_type] == 'CheckboxField' ? 1 : 2
      render layout: false
    end

    def update
      min_max
      custom_field_params = params[:custom_field].merge(
        sort_priority: @custom_field.sort_priority
      )
      custom_field_entity = build_custom_field_entity(@custom_field.type, custom_field_params)
      @custom_field.update(custom_field_entity)
      flash[:notice] = t('admin2.notifications.listing_field_updated')
    rescue StandardError => e
      flash[:error] = e.message
    ensure
      redirect_to admin2_listings_listing_fields_path
    end

    def delete_popup
      render layout: false
    end

    def create
      return unless params[:field_type].present?

      min_max
      custom_field_entity = build_custom_field_entity(params[:field_type], params[:custom_field])
      @custom_field = params[:field_type].constantize.new(custom_field_entity)
      @custom_field.entity_type = :for_listing
      @custom_field.community = @current_community
      if valid_categories?(@current_community, params[:custom_field][:category_attributes])
        @custom_field.save!
      else
        raise t('admin2.notifications.listing_field_saving_failed')
      end
      flash[:notice] = t('admin2.notifications.listing_field_created')
    rescue StandardError => e
      flash[:error] = e.message
    ensure
      redirect_to admin2_listings_listing_fields_path
    end

    def order
      sort_priorities = params[:order].each_with_index.map do |custom_field_id, index|
        [custom_field_id, index]
      end.inject({}) do |hash, ids|
        custom_field_id, sort_priority = ids
        hash.merge(custom_field_id.to_i => sort_priority)
      end
      @current_community.custom_fields.each do |custom_field|
        custom_field.update(sort_priority: sort_priorities[custom_field.id])
      end
      head :ok
    end

    def destroy
      @custom_field.destroy!
    rescue StandardError => e
      flash[:error] = e.message
    ensure
      redirect_to admin2_listings_listing_fields_path
    end

    private

    def min_max
      params[:custom_field][:min] = ParamsService.parse_float(params[:custom_field][:min]) if params[:custom_field][:min].present?
      params[:custom_field][:max] = ParamsService.parse_float(params[:custom_field][:max]) if params[:custom_field][:max].present?
    end

    def valid_categories?(community, category_attributes)
      is_community_category = category_attributes.map do |category|
        community.categories.any? { |community_category| community_category.id == category[:category_id].to_i }
      end
      is_community_category.all?
    end

    def field_type_is_valid
      if params[:field_type].present? && !CustomField::VALID_TYPES.include?(params[:field_type])
        redirect_to admin2_listings_listing_fields_path
      end
    end

    def build_custom_field_entity(type, params)
      params = params.respond_to?(:to_unsafe_hash) ? params.to_unsafe_hash : params
      case type
      when 'TextField'
        TextFieldEntity.call(params)
      when 'NumericField'
        NumericFieldEntity.call(params)
      when 'DropdownField'
        DropdownFieldEntity.call(params)
      when 'CheckboxField'
        CheckboxFieldEntity.call(params)
      when 'DateField'
        DateFieldEntity.call(params)
      end
    end

    def find_custom_field
      @custom_field = @current_community.custom_fields.find_by(id: params[:id])
    end
  end
end
