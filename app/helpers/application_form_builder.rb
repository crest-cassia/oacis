class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  def label_c(attribute, text=nil)
    label(attribute, text, class: 'col-md-2 control-label')
  end
end
