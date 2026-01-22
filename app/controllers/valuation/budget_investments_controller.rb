class Valuation::BudgetInvestmentsController < Valuation::BaseController
  include FeatureFlags
  include CommentableActions

  feature_flag :budgets

  before_action :restrict_access_to_assigned_items, only: [:show, :edit, :valuate]
  before_action :restrict_access, only: [:edit, :valuate]
  before_action :load_budget
  before_action :load_investment, only: [:show, :edit, :valuate]

  has_orders %w[oldest], only: [:show, :edit]
  has_filters %w[valuating valuation_finished], only: :index

  load_and_authorize_resource :investment, class: "Budget::Investment"

  def index
    @heading_filters = heading_filters
    @investments = if current_user.valuator? && @budget.present?
                     @budget.investments.visible_to_valuators.scoped_filter(params_for_current_valuator, @current_filter)
                            .order(cached_votes_up: :desc)
                            .page(params[:page])
                   else
                     Budget::Investment.none.page(params[:page])
                   end
  end

 def valuate
    # Procesar documentos manualmente
    if params[:budget_investment][:documents_attributes].present?
      process_documents_manually
      valuation_params_hash = valuation_params.to_h.except("documents_attributes")
    else
      valuation_params_hash = valuation_params.to_h
    end
    
    if valid_price_params? && @investment.update(valuation_params_hash)
      if @investment.unfeasible_email_pending?
        @investment.send_unfeasible_email
      end

      Activity.log(current_user, :valuate, @investment)
      notice = t("valuation.budget_investments.notice.valuate")
      # Agregar timestamp para forzar reload sin caché
      redirect_to valuation_budget_budget_investment_path(@budget, @investment, t: Time.now.to_i), notice: notice
    else
      render action: :edit
    end
  end

  def show
    # DEBUG
    Rails.logger.info "==== SHOW METHOD DEBUG ===="
    Rails.logger.info "Investment ID: #{@investment.id}"
    Rails.logger.info "Total documents via association: #{@investment.documents.count}"
    Rails.logger.info "Direct query Budget::Viabilidad: #{Document.where(documentable_id: @investment.id, documentable_type: 'Budget::Viabilidad').count}"
    Rails.logger.info "All documents for this investment: #{Document.where(documentable_id: @investment.id).pluck(:id, :title, :documentable_type).inspect}"
    
    # Limpiar caché
    ActiveRecord::Base.connection.clear_query_cache
    
    
    load_comments
  end

  def edit
    load_comments
  end

  private

    def process_documents_manually
      params[:budget_investment][:documents_attributes].each do |key, doc_attrs|
        if doc_attrs[:id].present?
          # Documento existente
          doc = Document.find_by(id: doc_attrs[:id], documentable_id: @investment.id)
          next unless doc
          
          if doc_attrs[:_destroy] == "1"
            # Eliminar documento
            doc.destroy
          else
            # SIEMPRE actualizar el título primero (viene del formulario con el nombre correcto)
            doc.title = doc_attrs[:title] if doc_attrs[:title].present?
            doc.documentable_type = doc_attrs[:documentable_type] if doc_attrs[:documentable_type].present?
            
            # Luego actualizar el attachment si hay uno nuevo
            if doc_attrs[:cached_attachment].present?
              doc.cached_attachment = doc_attrs[:cached_attachment]
              doc.set_attachment_from_cached_attachment
            elsif doc_attrs[:attachment].present?
              doc.attachment = doc_attrs[:attachment]
            end
            
            doc.save
          end
        else
          # Crear nuevo documento
          next if doc_attrs[:_destroy] == "1"
          
          doc = Document.new(
            attachment: doc_attrs[:attachment],
            title: doc_attrs[:title],
            user_id: doc_attrs[:user_id],
            cached_attachment: doc_attrs[:cached_attachment],
            documentable_type: doc_attrs[:documentable_type] || "Budget::Investment",
            documentable_id: @investment.id
          )
          doc.save
        end
      end
    end

    def load_comments
      @commentable = @investment
      @comment_tree = CommentTree.new(@commentable, params[:page], @current_order, valuations: true)
      set_comment_flags(@comment_tree.comments)
    end

    def resource_model
      Budget::Investment
    end

    def resource_name
      resource_model.parameterize(separator: "_")
    end

    def load_budget
      @budget = Budget.find_by_slug_or_id! params[:budget_id]
    end

    def load_investment
      @investment = @budget.investments.find params[:id]
    end

    def heading_filters
      investments = @budget.investments.by_valuator(current_user.valuator&.id).visible_to_valuators.distinct
      investment_headings = Budget::Heading.where(id: investments.pluck(:heading_id)).sort_by(&:name)

      all_headings_filter = [
                              {
                                name: t("valuation.budget_investments.index.headings_filter_all"),
                                id: nil,
                                count: investments.size
                              }
                            ]

      investment_headings.reduce(all_headings_filter) do |filters, heading|
        filters << {
                     name: heading.name,
                     id: heading.id,
                     count: investments.select { |i| i.heading_id == heading.id }.size
                   }
      end
    end

    def params_for_current_valuator
      Budget::Investment.filter_params(params).to_h.merge({ valuator_id: current_user.valuator.id,
                                                            budget_id: @budget.id })
    end

    def valuation_params
      params.require(:budget_investment).permit(:price, :price_first_year, :price_explanation,
                                                :feasibility, :unfeasibility_explanation,
                                                :duration, :valuation_finished,
                                                documents_attributes: [:id, :attachment, :title, :documentable_type, :cached_attachment, :user_id, :_destroy])
    end

    def restrict_access
      unless current_user.administrator? || current_budget.valuating?
        raise CanCan::AccessDenied.new(I18n.t("valuation.budget_investments.not_in_valuating_phase"))
      end
    end

    def restrict_access_to_assigned_items
      return if current_user.administrator? ||
                Budget::ValuatorAssignment.exists?(investment_id: params[:id],
                                                   valuator_id: current_user.valuator.id)

      raise ActionController::RoutingError.new("Not Found")
    end

    def valid_price_params?
      if /\D/.match params[:budget_investment][:price]
        @investment.errors.add(:price, I18n.t("budgets.investments.wrong_price_format"))
      end

      if /\D/.match params[:budget_investment][:price_first_year]
        @investment.errors.add(:price_first_year, I18n.t("budgets.investments.wrong_price_format"))
      end

      @investment.errors.empty?
    end
end