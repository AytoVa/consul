require_dependency Rails.root.join("app", "controllers", "verification", "residence_controller").to_s

class Verification::ResidenceController < ApplicationController
  def new
     Rails.logger.info "--- new custom ---"
    @residence = Verification::Residence.new
    @residence.document_type = current_user.document_type
    @residence.date_of_birth = current_user.date_of_birth
    @residence.postal_code = current_user.postal_code
  end

  def create
     Rails.logger.info "--- create  custommm---"
    @residence = Verification::Residence.new(residence_params.merge(user: current_user))
    if @residence.save
      current_user.update(verified_at: Time.now)
      redirect_to account_path, notice: t("verification.residence.create.flash.success")
    else
      render :new
    end

  rescue ArgumentError => e
    Rails.logger.info "--- no es una fecha valida ---"
    Rails.logger.info "--- Error capturado: #{e.message} ---"
    if e.message.include?("invalid date")
      @residence = Verification::Residence.new
      @residence.document_type = residence_params[:document_type]
      @residence.document_number = residence_params[:document_number]
      @residence.postal_code = residence_params[:postal_code]
      @residence.terms_of_service = residence_params[:terms_of_service]
      
      # NO asignar date_of_birth porque es inválida
      
      # Agregar el error manualmente
      @residence.errors.add(:date_of_birth, t("verification.residence.create.date.error"))
      
      render :new
    else
      raise e
    end
  end

end
