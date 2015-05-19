module ApplicationHelper

  def distance_to_now_in_words(datetime)
    if datetime
      return distance_of_time_in_words_to_now(datetime) + ' ago'
    else
      return ''
    end
  end

  def breadcrumb_links_for(document)
    links = []
    case document
    when Run
      links = breadcrumb_links_for(document.parameter_set)
      links << link_to("Run:#{document.id}", run_path(document))
    when ParameterSet
      links = breadcrumb_links_for(document.simulator)
      links << link_to("Param:#{document.id}", parameter_set_path(document))
    when Simulator
      links = [ link_to("Simulators", simulators_path) ]
      links << link_to(document.name, simulator_path(document))
    when Analysis
      links = breadcrumb_links_for(document.analyzable)
      links << "Analysis:#{document.id}"
    when Analyzer
      links = breadcrumb_links_for(document.simulator)
      links << "Analyzer:#{document.name}"
    else
      raise "not supported type"
    end
    return links
  end

  def progress_bar( total, num_success, num_danger, num_warning, num_submitted)
    percent_success = 0.0
    percent_danger = 0.0
    percent_warning = 0.0
    percent_submitted = 0.0
    if total.to_f > 0
      percent_success = ( num_success.to_f / total.to_f * 100 ).round
      percent_danger = ( num_danger.to_f / total.to_f * 100 ).round
      percent_warning = ( num_warning.to_f / total.to_f * 100 ).round
      percent_submitted = ( num_submitted.to_f / total.to_f * 100 ).round
    end

    tags = <<-EOS
      <div class="progress">
        #{progress_bar_tag_for('success', percent_success)}
        #{progress_bar_tag_for('danger', percent_danger)}
        #{progress_bar_tag_for('warning', percent_warning)}
        #{progress_bar_tag_for('info', percent_submitted)}
      </div>
    EOS
    raw(tags)
  end

  def shortened_id_monospaced(id)
    raw( '<tt class="short-id">' + shortened_id(id) + '</tt>' )
  end

  def shortened_id(id)
    str = id.to_s
    str[3..6] + ".." + str[-3..-1]
  end

  def shortened_job_id(job_id)
    short = job_id.to_s
    short = short[0..5] + ".." if short.length > 6
    short
  end

  private
  MIN_PERCENT_TO_PRINT = 5
  def progress_bar_tag_for(status, percent)
    content = percent > MIN_PERCENT_TO_PRINT ? "#{percent}%" : ""
    tag = <<-EOS
      <div class="progress-bar progress-bar-#{status}" style="width: #{percent}%">#{content}</div>
    EOS
  end

  # to prevent UTF-8 parameter from being added in the URL for GET requests
  # See http://stackoverflow.com/questions/4104474/rails-3-utf-8-query-string-showing-up-in-url
  def utf8_enforcer_tag
    return "".html_safe
  end

  def link_to_add_fields(name, f, association, partial = nil)
    new_object = f.object.send(association).klass.new
    id = new_object.object_id
    fields = f.fields_for(association, new_object, child_index: id) do |builder|
      partial ||= association.to_s.singularize + "_fields"
      render(partial, f: builder)
    end
    link_to(name, '#', class: "add_fields", data: {id: id, fields: fields.gsub("\n", "")})
  end
end
