# Done on close — pri prechode do vybraného uzavretého stavu nastaví % Done na 100.
#
# Prečo plugin a nie vstavané nastavenie: Redmine vie počítať % Done zo stavu
# (Setting.issue_done_ratio = 'issue_status'), ale tým pole úplne zmizne z formulára,
# hromadných úprav aj kontextového menu a nikto ho už nenastaví ručne. Tento plugin
# pole necháva tak, ako je, a len ho pri zatvorení dorovná.
require_relative 'lib/done_on_close'

Redmine::Plugin.register :redmine_done_on_close do
  name 'Done on close'
  author 'Martin Kopáč'
  description 'Sets % Done to 100 when an issue moves into a selected closed status.'
  version '0.1.0'
  url 'https://github.com/martinkopac19/redmine_done_on_close'
  requires_redmine version_or_higher: '5.0'

  settings default: { 'status_ids' => [] },
           partial: 'settings/done_on_close'
end

# Patch je zámerne tu a nie v `to_prepare` — ten sa v production nespúšťa a patch by
# ticho nikdy nenabehol. Rovnako to majú ostatné pluginy v tomto Redmine.
unless Issue.included_modules.include?(DoneOnClose::IssuePatch)
  Issue.prepend(DoneOnClose::IssuePatch)
end
