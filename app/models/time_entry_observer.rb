class TimeEntryObserver < ActiveRecord::Observer

  def after_update(time_entry)
    if time_entry.approval_status== false
      Thread.new { Mailer.time_entry_rejected(time_entry).deliver }
    end
  end
end
