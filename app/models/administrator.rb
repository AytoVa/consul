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
    Budget::Investment.where(author_id: user_id).destroy_all
  end

end
