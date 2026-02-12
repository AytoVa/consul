require_dependency Rails.root.join("app", "models", "verification", "residence").to_s

class Verification::Residence
  validate :postal_code_in_valladolid
  validate :residence_in_valladolid
  validate :document_number_and_document_type

  def postal_code_in_valladolid
    errors.add(:postal_code, I18n.t("verification.residence.new.error_not_allowed_postal_code")) unless valid_postal_code?
  end

  def residence_in_valladolid
    return if errors.any?

    unless residency_valid?
      errors.add(:residence_in_valladolid, false)
      store_failed_attempt
      Lock.increase_tries(user)
    end
  end

  def save
       
    Rails.logger.info "--- se los datos del usuario---"
    if !valid?         
      return false
    end
    
    if !@census_data.valid?
      Rails.logger.info "--- El padrón no devuelve respuesta válida --"
      errors.add(:estado, I18n.t("verification.residence.new.error_verifying_census"))
      return false
    end


    Rails.logger.info "--- Se comprueba estado ---"     
    Rails.logger.info "--- El padrón devuelve el estado #{@census_data.estado} --"
    if @census_data.estado.in?([0, 2, "0", "2"])
      Rails.logger.info "--- El padrón devuelve el estado #{@census_data.estado} --"
      errors.add(:estado, I18n.t("verification.residence.new.error_verifying_estado"))
      return false
    end

    
    user.take_votes_if_erased_document(document_number, document_type)

    user.update(document_number:       document_number,
                document_type:         document_type,
                # geozone:               geozone,
                date_of_birth:         @census_data.date_of_birth.in_time_zone.to_datetime,
                # gender:                gender,
                postal_code:           @census_data.postal_code,
                residence_verified_at: Time.current)
  end

  def document_number_and_document_type
    if (document_type.to_s == "1" || document_type.to_s == "3") && document_number.length != 9
      errors.add(:document_number, I18n.t("errors.messages.document_number_and_document_type"))
    end
  end

  def document_number_uniqueness
    if User.active.where(document_number: document_number).where("id != ?", user.id).any?
      errors.add(:document_number, I18n.t("errors.messages.taken"))
    end
  end

  private

    def valid_postal_code?
      postal_code =~ /^47/
    end
end
