class Consultation::CodesController < Consultation::BaseController
  def index
    @residence = Verification::Residence.new
  end

  def check
    document_type = residence_params[:document_type]
    document_number = residence_params[:document_number].gsub(/[^a-z0-9]+/i, "").upcase
    postal_code = residence_params[:postal_code]
    date_of_birth = Date.new(residence_params["date_of_birth(1i)"].to_i, residence_params["date_of_birth(2i)"].to_i, residence_params["date_of_birth(3i)"].to_i) rescue nil
    terms_of_service = residence_params[:terms_of_service]

    @error = nil

    if document_type.present? && document_number.present? && postal_code.present? && date_of_birth.present? && terms_of_service == "1"
      @census_api_response = CensusvaApi.new.call(residence_params[:document_type], document_number)

      if !postal_code.start_with?("47") 
        @error = t("verification.residence.ad.error_verifying_ad_cp") 
      elsif  !@census_api_response.valid?         
        @error = t("verification.residence.ad.error_verifying_ad_response")   
      elsif @census_api_response.estado.in?([0, 2, "0", "2"])
        @error = t("verification.residence.ad.error_verifying_ad_estado")       
      elsif @census_api_response.postal_code != postal_code
        @error = t("verification.residence.ad.error_verifying_ad_cp_distint")
      elsif @census_api_response.date_of_birth != date_of_birth
           @error = t("verification.residence.ad.error_verifying_ad_db_distint") 
      else
        @codigo = Codigo.find_by(clave: document_number)&.valor 
        @error = t("codigos.errors.not_found") if @codigo.blank?     
      end
    else
      @error = t("codigos.errors.form")
    end

    if @error.present?
      redirect_to consultation_codes_path(params: residence_params), flash: { error: @error }
    end
  end

  private

    def residence_params
      params.require(:residence).permit(:document_number, :document_type, :date_of_birth, :postal_code, :terms_of_service, :format)
    end
end
