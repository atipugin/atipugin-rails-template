module ClassSetHelper
  # Inspired by http://facebook.github.io/react/docs/class-name-manipulation.html
  def class_set(h = {})
    classes = []
    h.each do |class_name, condition|
      classes << class_name if condition
    end

    classes.map { |c| c.to_s.gsub(/\s+/, ' ').split(' ') }
      .flatten
      .map(&:strip)
      .select(&:presence)
      .uniq
      .join(' ')
  end
end
