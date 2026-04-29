class Valuator < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :valuator_group

  delegate :name, :email, :name_and_email, to: :user

  has_many :valuator_assignments, dependent: :destroy, class_name: "Budget::ValuatorAssignment"
  has_many :investments, through: :valuator_assignments, class_name: "Budget::Investment"

  validates :user_id, presence: true, uniqueness: true

  def description_or_email
    description.presence || email
  end

  def description_or_name
    description.presence || name
  end

  def assigned_investment_ids
    investment_ids + valuator_group&.investment_ids.to_a
  end

  # Elimina los budget_valuators antes de eliminar el evaluador
  before_destroy :destroy_budget_valuators

  private

  def destroy_budget_valuators
    Rails.logger.info "=== ELIMINANDO LÓGICAMENTE BUDGET VALUATORS ==="
    Rails.logger.info "User ID: #{self.user_id}"
    
     valuator = Valuator.find_by(user_id: self.user_id)

    if valuator
      budget_valuators = BudgetValuator.where(valuator: valuator)
      Rails.logger.info "BudgetValuators encontrados: #{budget_valuators.count}"
      
      count = budget_valuators.count
      budget_valuators.destroy_all
      Rails.logger.info "BudgetValuators eliminados: #{count}"
    else
      Rails.logger.info "No se encontró Valuator para user_id: #{self.user_id}"
    end
  end

end
