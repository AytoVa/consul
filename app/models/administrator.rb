class Administrator < ApplicationRecord
  belongs_to :user, touch: true
  delegate :name, :email, :name_and_email, to: :user

  validates :user_id, presence: true, uniqueness: true

  scope :with_user, -> { includes(:user) }

  def description_or_name
    description.presence || name
  end

  def description_or_name_and_email
    "#{description_or_name} (#{email})"
  end

 # Elimina los budget_investments antes de eliminar el administrador
  before_destroy :destroy_budget_investments

  private

  def destroy_budget_investments
   Rails.logger.info "=== ELIMINANDO LÓGICAMENTE BUDGET INVESTMENTS ==="
    Rails.logger.info "User ID: #{self.user_id}"
    
    # Obtén solo los que no están ya eliminados
    investments = Budget::Investment.where(author_id: self.user_id, hidden_at: nil)
    Rails.logger.info "Budget Investments activos encontrados: #{investments.count}"
    
    # Marca como eliminados lógicamente
    count = investments.update_all(hidden_at: Time.current)
    
    Rails.logger.info "Budget Investments marcados como eliminados: #{count}"
  end

end
