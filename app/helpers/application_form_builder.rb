class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  def label_with_tooltip(attribute, text, *json_path)
    json = TOOLTIP_DESCS
    Rails.logger.debug "json_path:" + json_path.to_s
    json = json.dig(*json_path)
    if json.present? && json.is_a?(String)
      label(attribute, text, class: 'col-md-2 control-label',  data: {html: 'true', toggle: 'tooltip'}, title: "#{json}")
    else
      label(attribute, text, class: 'col-md-2 control-label')
    end
  end
end
