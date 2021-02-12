class OacisSettingsController < ApplicationController
  before_action :set_oacis_setting, only: %i[edit update]

  def edit
  end

  def update
    @oacis_setting.assign_attributes(oacis_setting_params)
    webhook_url_changed = @oacis_setting.webhook_url_changed?
    if @oacis_setting.update
      success_message = 'Oacis setting was successfully updated.'
      SlackNotifier.new(@oacis_setting.webhook_url).notify(message: success_message, color: 'good') if @oacis_setting.webhook_url.present? && webhook_url_changed

      redirect_to edit_oacis_setting_path, notice: success_message
    else
      render :edit
    end
  end

  private

  def set_oacis_setting
    @oacis_setting = OacisSetting.instance
  end

  def oacis_setting_params
    params.require(:oacis_setting).permit(:notification_level, :webhook_url, :oacis_url)
  end
end
