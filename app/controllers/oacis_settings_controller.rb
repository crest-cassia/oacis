class OacisSettingsController < ApplicationController
  before_action :set_oacis_setting, only: %i[edit update]

  def edit
  end

  def update
    if @oacis_setting.update(oacis_setting_params)
      redirect_to edit_oacis_setting_path, notice: 'Oacis setting was successfully updated.'
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
