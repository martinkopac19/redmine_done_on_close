require_relative 'done_on_close/issue_patch'

module DoneOnClose
  module_function

  # Stavy, pri ktorých sa má % Done dorovnať na 100. Držia sa ako ID, nie názvy —
  # premenovanie stavu v Administration tak automatizáciu nezhodí.
  def enabled_status_ids
    Array(Setting.plugin_redmine_done_on_close['status_ids']).map(&:to_i).reject(&:zero?)
  end
end
