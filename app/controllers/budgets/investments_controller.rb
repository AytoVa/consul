module Budgets
  class InvestmentsController < ApplicationController
    include FeatureFlags
    include CommentableActions
    include FlagActions
    include RandomSeed
    include ImageAttributes
    include Translatable

    PER_PAGE = 10

    before_action :authenticate_user!, except: [:index, :show, :json_data]
    before_action :load_budget, except: :json_data
    
    before_action :verificar_permiso_creacion, only: [:new, :create]


    load_and_authorize_resource :budget, except: [:json_data, :vote, :unvote]
    load_and_authorize_resource :investment, through: :budget, class: "Budget::Investment",
                                except: [:json_data, :vote, :unvote]

    before_action :load_ballot, only: [:index, :show]
    before_action :load_heading, only: [:index, :show]
    before_action :set_random_seed, only: :index
    before_action :load_categories, only: [:index, :new, :create, :edit, :update]
    before_action :set_default_budget_filter, only: :index
    before_action :set_view, only: :index
    before_action :load_content_blocks, only: :index

    skip_authorization_check only: [:json_data, :unvote, :vote]

    feature_flag :budgets

    has_orders %w[most_voted newest oldest], only: :show
    has_orders ->(c) { c.instance_variable_get(:@budget).investments_orders }, only: :index

    valid_filters = %w[not_unfeasible feasible unfeasible unselected selected winners]
    has_filters valid_filters, only: [:index, :show, :suggest]

    invisible_captcha only: [:create, :update], honeypot: :subtitle, scope: :budget_investment

    helper_method :resource_model, :resource_name
    respond_to :html, :js

    def index
      @lock_reason = nil  # 👈 Inicializar SIEMPRE
      
      if current_user
        if current_user.document_number
          Rails.logger.info "Verificando usuario en PADRON"
          response = in_census
          
          if response.present?
            if response.estado == "0" || response.estado == "2"
              Rails.logger.info "Usuario NO empadronado (estado 0 o 2)"
              @lock_reason = :not_registered
              lock_user_all_types
              
            elsif response.date_of_birth != current_user.date_of_birth.to_date
              Rails.logger.info "Fecha de nacimiento NO coincide"
              @lock_reason = :birth_date_mismatch
              lock_user_all_types
              
            elsif response.postal_code != current_user.postal_code
              Rails.logger.info "Código postal NO coincide"
              @lock_reason = :postal_code_mismatch  # 👈 ASIGNAR SIEMPRE
              lock_user_all_types
              
            else
              Rails.logger.info "Usuario verificado correctamente"
              # Verificar si ya estaba bloqueado antes
              @locked_user = Budget::LockedUser.where(
                document_number: current_user.document_number,
                document_type: current_user.document_type,
                budget_id: @budget.id
              )
              @already_locked = @locked_user.present?
              @lock_reason = nil  # 👈 Usuario OK, sin bloqueo
            end
          else
            Rails.logger.info "Usuario NO existe en PADRON"
            @lock_reason = :not_in_census
            lock_user_all_types
          end
        else
          Rails.logger.info "Usuario sin document_number"
          @lock_reason = :no_document
          lock_user_all_types
        end
        
        # 👇 VERIFICAR SI YA ESTÁ BLOQUEADO (aunque no tengamos response)
        if @lock_reason.nil?
         Rails.logger.info "VERIFICAR SI YA ESTÁ BLOQUEADO: #{@lock_reason.inspect}"
         Rails.logger.info "current_user.username: #{current_user.username}"  
          existing_lock = Budget::LockedUser.where(
            document_number: current_user.document_number,
            document_type: ['1', '2', '3'],
            budget_id: @budget.id
          ).first
          Rails.logger.info "existing_lock: #{existing_lock.inspect}"
          if existing_lock
            # Usuario ya está bloqueado, determinar el motivo
            @lock_reason = :user_locked  # Motivo genérico si no sabemos cuál es
            Rails.logger.info "Usuario encontrado bloqueado previamente"
          end
        end
      else
        @already_locked = false
      end
      
      Rails.logger.info "LOCK_REASON FINAL: #{@lock_reason.inspect}"  # 👈 LOG PARA DEBUG
      
      @investments = investments.page(params[:page]).per(PER_PAGE).for_render
      @investment_ids = @investments.pluck(:id)
      @investments_map_coordinates = MapLocation.where(investment: investments).map(&:json_data)
      
      load_investment_votes(@investments)
      @tag_cloud = tag_cloud
      @remote_translations = detect_remote_translations(@investments)
    end

    def new
    end

    def show
		if (current_user)
			if (current_user.document_number)
				@locked_user = Budget::LockedUser.where(document_number: current_user.document_number, document_type: current_user.document_type, budget_id: @budget.id)
				@already_locked = @locked_user.present?
			else
				 lock_user_all_types
			end
		else
			@already_locked = false
		end
      @commentable = @investment
      @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
      @related_contents = Kaminari.paginate_array(@investment.relationed_contents).page(params[:page]).per(5)
      set_comment_flags(@comment_tree.comments)
      load_investment_votes(@investment)
      @investment_ids = [@investment.id]
      @remote_translations = detect_remote_translations([@investment], @comment_tree.comments)
    end

    def create
      @investment.author = current_user

      if @investment.save
        Mailer.budget_investment_created(@investment).deliver_later
        redirect_to budget_investment_path(@budget, @investment),
                    notice: t("flash.actions.create.budget_investment")
      else
        render :new
      end
    end

    def update
      if @investment.update(investment_params)
        redirect_to budget_investment_path(@budget, @investment),
                    notice: t("flash.actions.update.budget_investment")
      else
        render "edit"
      end
    end

    def destroy
      @investment.destroy!
      redirect_to user_path(current_user, filter: "budget_investments"), notice: t("flash.actions.destroy.budget_investment")
    end

    def vote
      @budget = Budget.find_by_slug_or_id!(params[:budget_id])
      @investment = @budget.investments.find(params[:id])
      
      @investment.register_selection(current_user)
      load_investment_votes(@investment)
      respond_to do |format|
        format.html { redirect_to budget_investments_path(heading_id: @investment.heading.id) }
        format.js
      end
    end
    
    def unvote
      @budget = Budget.find_by_slug_or_id!(params[:budget_id])
      @investment = @budget.investments.find(params[:id])
      
      Rails.logger.info "="*50
      Rails.logger.info "ENTRANDO A UNVOTE"
      Rails.logger.info "Budget: #{@budget.id}"
      Rails.logger.info "Investment: #{@investment.id}"
      Rails.logger.info "="*50
      
      @investment.unvote_by(current_user)  # ← ESTE ES EL MÉTODO CORRECTO
      
      load_investment_votes(@investment)
      
      respond_to do |format|
        format.js { render :vote }
        format.html { redirect_to budget_investments_path(budget_id: @budget.id, heading_id: @investment.heading&.id) }
      end
    end
    
    def suggest
      @resource_path_method = :namespaced_budget_investment_path
      @resource_relation    = resource_model.where(budget: @budget).apply_filters_and_search(@budget, params, @current_filter)
      super
    end

    def json_data
      investment = Budget::Investment.find(params[:id])
      data = {
        investment_id: investment.id,
        investment_title: investment.title,
        budget_id: investment.budget.id
      }.to_json

      respond_to do |format|
        format.json { render json: data }
      end
    end

    private
      # Método auxiliar para comprobar si existe en el censo
      def in_census        
          response = CensusCaller.new.call(current_user.document_type, current_user.document_number, current_user.date_of_birth, current_user.postal_code)
          
          if response.valid?
            @census_api_response = response
            return response  # 👈 Devuelve el response directamente
          end       
        
        nil  # Si ninguno fue válido, devuelve nil
      end

      # Método auxiliar para bloquear al usuario en los 3 tipos
      def lock_user_all_types
        ['1', '2', '3'].each do |doc_type|
          Budget::LockedUser.find_or_create_by(
            document_number: current_user.username,
            document_type: doc_type,
            budget_id: @budget.id
          )
        end
        @already_locked = true
      end

      def resource_model
        Budget::Investment
      end

      def resource_name
        "budget_investment"
      end

      def load_investment_votes(investments)
        @investment_votes = current_user ? current_user.budget_investment_votes(investments) : {}
      end

     def investment_params
        attributes = [:heading_id, :tag_list,
                      :organization_name, :location, :terms_of_service, :skip_map, :zona_mesa,
                      image_attributes: image_attributes,
                      documents_attributes: [:id, :title, :attachment, :cached_attachment, :user_id, :_destroy],
                      map_location_attributes: [:latitude, :longitude, :zoom]]
        
        permitted = params.require(:budget_investment).permit(attributes, translation_params(Budget::Investment))
        
        # Limpiar documents_attributes que no tienen cambios reales
        if permitted[:documents_attributes]
          permitted[:documents_attributes].each do |key, doc_params|
            # Primero limpiar cached_attachment vacío
            doc_params.delete(:cached_attachment) if doc_params[:cached_attachment].blank?
            
            # Determinar si se va a destruir (puede venir como "1", "true", true, 1)
            is_destroy = ["1", "true", true, 1].include?(doc_params[:_destroy])
            
            # Si el documento ya existe (tiene ID) Y NO se va a destruir
            if doc_params[:id].present? && !is_destroy
              existing_doc = Document.find_by(id: doc_params[:id])
              
              if existing_doc
                # Verificar si hay cambios reales
                has_changes = false
                has_changes = true if doc_params[:title] && doc_params[:title] != existing_doc.title
                has_changes = true if doc_params[:attachment].present?
                has_changes = true if doc_params[:cached_attachment].present?
                
                # Si NO hay cambios, eliminar este documento de los parámetros
                unless has_changes
                  permitted[:documents_attributes].delete(key)
                end
              end
            end
          end
        end
        
        # Limpiar image_attributes cached_attachment vacío también
        if permitted[:image_attributes] && permitted[:image_attributes][:cached_attachment].blank?
          permitted[:image_attributes].delete(:cached_attachment)
        end
        
        permitted
      end

      def load_ballot
        query = Budget::Ballot.where(user: current_user, budget: @budget)
        @ballot = @budget.balloting? ? query.first_or_create! : query.first_or_initialize
      end

      def load_heading
        if params[:heading_id].present?
          @heading = @budget.headings.find_by_slug_or_id! params[:heading_id]
          @assigned_heading = @ballot&.heading_for_group(@heading&.group)
          load_map
        end
      end

      def load_categories
        @categories = Tag.category.order(:name)
      end

      def load_content_blocks
        @heading_content_blocks = @heading.content_blocks.where(locale: I18n.locale) if @heading
      end

      def tag_cloud
        TagCloud.new(Budget::Investment, params[:search])
      end

      def load_budget
        @budget = Budget.find_by_slug_or_id! params[:budget_id]
      end

      def set_view
        @view = (params[:view] == "minimal") ? "minimal" : "default"
      end

      def investments
        if @current_order == "random"
          @budget.investments.apply_filters_and_search(@budget, params, @current_filter)
                             .sort_by_random(session[:random_seed])
        else
          @budget.investments.apply_filters_and_search(@budget, params, @current_filter)
                             .send("sort_by_#{@current_order}")
        end
      end

      def load_map
        @map_location = MapLocation.load_from_heading(@heading)
      end
      
     def verificar_permiso_creacion
      if !current_user.organization? && Budget::Investment.valuating_investment(current_user.id, @budget.id).count > 0
        redirect_to budgets_path, alert: t("budgets.investments.index.sidebar.message_error_my_count")
      elsif current_user.organization? && Budget::Investment.valuating_investment_number(current_user.id, @budget.id).count > 4
        redirect_to budgets_path, alert: t("budgets.investments.index.sidebar.message_error_my_propuestas")
      end
    end

  end
end