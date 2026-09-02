module DoneOnClose
  module IssuePatch
    def self.prepended(base)
      base.class_eval do
        before_save :done_on_close_fill_ratio
      end
    end

    private

    # Beží ako before_save, aby sa zmena stihla dostať aj do histórie úlohy
    # (Redmine skladá detaily journalu z porovnania atribútov pri ukladaní).
    def done_on_close_fill_ratio
      # Len pri PRECHODE do stavu, nie pri každom ďalšom uložení už zatvorenej úlohy —
      # inak by sa nedalo zatvorenej úlohe zámerne nechať nižšie %.
      return unless will_save_change_to_status_id?
      return unless DoneOnClose.enabled_status_ids.include?(status_id)

      # V režime „% Done podľa stavu" si hodnotu riadi jadro a pole vo formulári neexistuje.
      return unless Issue.use_field_for_done_ratio?

      # Rodičovská úloha s odvodeným %: hodnotu počíta jadro z podúloh, zápis by sa aj tak stratil.
      return if done_ratio_derived?

      self.done_ratio = 100
    end
  end
end
