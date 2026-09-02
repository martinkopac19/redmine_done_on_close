# Selftest pluginu redmine_done_on_close.
# Beží proti živej DB, ale VŠETKO je v transakcii, ktorá sa na konci zahodí —
# klon obsahuje reálne produkčné dáta, takže po sebe nesmie zostať ani stopa.
#
# Spustenie:
#   docker compose exec -T --user redmine -e SECRET_KEY_BASE=... redmine \
#     bin/rails runner -e production plugins/redmine_done_on_close/extra/selftest.rb

$ok = 0
$bad = 0

def check(name, actual, expected)
  if actual == expected
    $ok += 1
    puts "  #{name.ljust(46)}: OK"
  else
    $bad += 1
    puts "  #{name.ljust(46)}: CHYBA (ocakavane #{expected.inspect}, prislo #{actual.inspect})"
  end
end

# Vyberie prvu ulohu zo scope, ktora sa po zmene stavu da naozaj ulozit. Niektore projekty
# maju povinnu kategoriu alebo custom field a validacia by spadla na nieco, co s pluginom
# vobec nesuvisi — testujeme spravanie pluginu, nie validacie jadra.
def pick_saveable(scope, status, user, limit = 120)
  scope.limit(limit).detect do |i|
    c = Issue.find(i.id)
    # init_journal MUSI byt aj tu: Redmine berie povinne polia z workflow podla
    # pouzivatela v journale, takze bez neho je valid? mieknejsi nez skutocny save.
    c.init_journal(user)
    c.status = status
    c.valid?
  end
end

# Zatvori ulohu tak, ako to robi pouzivatel cez formular (vratane journalu).
def close_as_user(issue, status, user)
  issue.init_journal(user)
  issue.status = status
  issue.save!
  issue.reload
end

closed   = IssueStatus.find_by(:name => 'Closed')
rejected = IssueStatus.find_by(:name => 'Rejected')
resolved = IssueStatus.find_by(:name => 'Resolved')
user     = User.active.where(:admin => true).first

puts "Stavy: Closed=#{closed&.id} Rejected=#{rejected&.id} Resolved=#{resolved&.id}"
puts "Nastavenie pluginu: #{DoneOnClose.enabled_status_ids.inspect}"
puts

ActiveRecord::Base.transaction do
  open_ids = IssueStatus.where(:is_closed => false).pluck(:id)
  leaves   = Issue.where(:status_id => open_ids, :done_ratio => 0)
                  .where("NOT EXISTS (SELECT 1 FROM issues c WHERE c.parent_id = issues.id)")
                  .order(:id)

  # --- 1. bezny leaf task -> Closed ---------------------------------------
  leaf = pick_saveable(leaves, closed, user)
  puts "[1] Leaf uloha ##{leaf.id} (done_ratio #{leaf.done_ratio}) -> Closed"
  close_as_user(leaf, closed, user)
  check("done_ratio po zatvoreni", leaf.done_ratio, 100)
  det = leaf.journals.last.details.detect { |d| d.prop_key == 'done_ratio' }
  check("zmena je v historii ulohy", !det.nil?, true)
  check("historia: z coho na co", det && [det.old_value.to_i, det.value.to_i], [0, 100])
  puts

  # --- 2. Rejected sa nema dotknut ----------------------------------------
  rej = pick_saveable(leaves.where.not(:id => leaf.id), rejected, user)
  puts "[2] Uloha ##{rej.id} -> Rejected (nie je v nastaveni)"
  close_as_user(rej, rejected, user)
  check("done_ratio zostava 0", rej.done_ratio, 0)
  puts

  # --- 3. Resolved sa nema dotknut ----------------------------------------
  res = pick_saveable(leaves.where.not(:id => [leaf.id, rej.id]), resolved, user)
  puts "[3] Uloha ##{res.id} -> Resolved (nie je v nastaveni)"
  close_as_user(res, resolved, user)
  check("done_ratio zostava 0", res.done_ratio, 0)
  puts

  # --- 4. Uz zatvorenej ulohe sa da % znizit rucne -------------------------
  puts "[4] Uz zatvorenej ulohe ##{leaf.id} nastavim rucne 80 %"
  leaf.init_journal(user)
  leaf.done_ratio = 80
  leaf.save!
  leaf.reload
  check("rucna hodnota prezije (netrigeruje sa znova)", leaf.done_ratio, 80)
  puts

  # --- 5. Rodic s odvodenym % sa nema prepisat ----------------------------
  # Zamerne rodic POD 100 %: keby uz mal 100, test by nerozlisil "nezmenilo sa"
  # od "plugin ho nastavil na 100" a nedokazal by nic.
  parents = Issue.where(:status_id => open_ids)
                 .where("done_ratio < 100")
                 .where("EXISTS (SELECT 1 FROM issues c WHERE c.parent_id = issues.id)")
                 .order(:id)
  parent = pick_saveable(parents, closed, user)
  if parent && Setting.parent_issue_done_ratio == 'derived'
    before = parent.done_ratio
    puts "[5] Rodicovska uloha ##{parent.id} (odvodene #{before} %) -> Closed"
    close_as_user(parent, closed, user)
    check("odvodene % sa nezmenilo na 100", parent.done_ratio, before)
  else
    puts "[5] preskocene (nenasiel sa ulozitelny rodic alebo nie je rezim derived)"
  end
  puts

  # --- 6. Stare zatvorene ulohy sa nemenia --------------------------------
  old = Issue.where(:status_id => closed.id).where("done_ratio < 100").first
  puts "[6] Stara zatvorena uloha ##{old.id} (done_ratio #{old.done_ratio}) — bez zasahu"
  check("stara uloha zostava pod 100 %", old.reload.done_ratio < 100, true)
  puts

  raise ActiveRecord::Rollback
end

puts "=" * 60
puts "OK: #{$ok}   CHYBA: #{$bad}"
puts "(vsetky zmeny zahodene, v DB nezostalo nic)"
