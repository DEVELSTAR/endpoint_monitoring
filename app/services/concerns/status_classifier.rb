module StatusClassifier
  extend ActiveSupport::Concern

  def determine_status_from_counts(good_count, warning_count, critical_count, down_count)
    total = good_count + warning_count + critical_count + down_count
    return "down" if total == 0

    down_ratio = down_count.to_f / total
    critical_ratio = critical_count.to_f / total
    warning_ratio = warning_count.to_f / total

    if down_ratio >= 0.5 && down_count > 0
      "down"
    elsif (down_ratio + critical_ratio) >= 0.5 && critical_count > 0
      "critical"
    elsif (down_ratio + critical_ratio + warning_ratio) > 0.5
      "warning"
    else
      "good"
    end
  end
end
