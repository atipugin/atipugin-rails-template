module BodyClassHelper
  def body_class
    classes = content_for(:body_class)
      .to_s
      .split(' ')
      .map(&:strip)
      .select(&:presence)

    (classes + default_classes).join(' ')
  end

  private

  def default_classes
    [controller_name, "#{controller_name}-#{action_name}"]
  end
end
