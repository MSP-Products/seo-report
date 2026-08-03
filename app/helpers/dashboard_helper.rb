module DashboardHelper
  GENERATION_STATUS_BADGE = {
    "ready" => "bg-emerald-50 text-emerald-700",
    "generating" => "bg-teal-primary/10 text-teal-dark",
    "queued" => "bg-slate-100 text-slate-600",
    "failed" => "bg-red-50 text-red-700"
  }.freeze

  def generation_status_badge_class(report)
    GENERATION_STATUS_BADGE.fetch(report.generation_status, "bg-slate-100 text-slate-600")
  end

  def generation_status_label(report)
    return "Failed ×#{report.attempt_count}" if report.failed? && report.attempt_count > 1

    report.generation_status.capitalize
  end

  def send_status_label(report)
    return "Sent" if report.emailed_at.present?
    return "Held" if report.send_logs.any?(&:held?)
    return "—" unless report.ready?

    "Not sent"
  end

  def send_status_badge_class(report)
    return "bg-emerald-50 text-emerald-700" if report.emailed_at.present?
    return "bg-amber-50 text-amber-700" if report.send_logs.any?(&:held?)

    "bg-slate-100 text-slate-600"
  end

  # The real reason a send is held, e.g. "HubSpot token rejected" — surfaced
  # next to the badge rather than leaving "Held" unexplained.
  def held_reason(report)
    report.send_logs.find(&:held?)&.error_message
  end

  def duration_in_words(seconds)
    return "0s" if seconds.nil? || seconds < 1

    minutes, secs = seconds.to_i.divmod(60)
    return "#{secs}s" if minutes.zero?

    hours, mins = minutes.divmod(60)
    return "#{mins}m #{secs}s" if hours.zero?

    "#{hours}h #{mins}m"
  end
end
