class Management::UsersController < Management::BaseController

  def new
    @user = User.new(user_params)
  end

  def create
    @user = User.new(user_params)
    @user.skip_password_validation = true
    @user.skip_email_validation = true
    @user.terms_of_service = '1'

    @user.created_by = current_manager["login"].to_s.scan(/\d/).join('').to_i


    if Rails.application.secrets.census_validate != "disabled"
      @user.residence_verified_at = Time.current
      @user.verified_at = Time.current
    end

    if @user.email.to_s.empty?
      @user.email = nil
    end

    if @user.save then
      render :show
    else
      render :new
    end
  end

  def erase
    managed_user.erase(t("management.users.erased_by_manager", manager: current_manager['login'])) if current_manager.present?
    destroy_session
    redirect_to management_document_verifications_path, notice: t("management.users.erased_notice")
  end

  def logout
    destroy_session
    redirect_to management_root_url, notice: t("management.sessions.signed_out_managed_user")
  end

  private

    def user_params
      params.require(:user).permit(:document_type, :document_number, :username, :email, :date_of_birth)
    end

    def destroy_session
      session[:document_type] = nil
      session[:document_number] = nil
    end

end
