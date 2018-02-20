class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  def label_with_tooltip(attribute, text=nil, json_path_arr)
    if json_path_arr.blank? || !json_path_arr.is_a?(Array)
      return label(attribute, text, class: 'col-md-2 control-label')
    end

    json = TOOLTIP_DESCS
    json_path_arr.each do |p|
      json = json["#{p}"] rescue nil
      break if json.nil?
    end
    if json.present? && json.is_a?(String)
      label(attribute, text, class: 'col-md-2 control-label',  data: {html: 'true', toggle: 'tooltip'}, title: "#{json}")
    else
      label(attribute, text, class: 'col-md-2 control-label')
    end
  end
end
