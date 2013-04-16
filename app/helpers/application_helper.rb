module ApplicationHelper

  def distance_to_now_in_words(datetime)
    if datetime
      return distance_of_time_in_words_to_now(datetime) + ' ago'
    else
      return ''
    end
  end
end
