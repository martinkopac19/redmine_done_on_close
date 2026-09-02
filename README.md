# Done on close

Keď úloha prejde do vybraného uzavretého stavu, plugin jej nastaví **% Done na 100**.
Nič viac.

## Prečo plugin a nie vstavané nastavenie

Redmine vie počítať % Done zo stavu — *Administration → Settings → Issue tracking →
„Calculate the issue done ratio with" → „Use the issue status"*. Vyzerá to ako presne toto
a nepotrebuje ani riadok kódu.

**Má to ale háčik: pole % Done tým úplne zmizne** z formulára úlohy, z hromadných úprav aj
z kontextového menu (`Issue.use_field_for_done_ratio?` v jadre). Hodnota sa potom odvíja
výhradne od stavu a nikto ju nemôže nastaviť ručne.

Ak tím % Done nastavuje aj ručne, je to neprijateľná cena — a presne to bol náš prípad.
Plugin preto pole necháva tak, ako je, a len ho pri zatvorení dorovná.

## Nastavenie

*Administration → Plugins → Done on close → Configure*

Zaškrtneš stavy, pri ktorých sa má % Done nastaviť na 100. Ponúkajú sa len **uzavreté**
stavy. Stavy sa ukladajú ako ID, nie ako názvy, takže premenovanie stavu automatizáciu
nezhodí.

## Čo plugin zámerne NErobí

- **Nemení existujúce úlohy.** Uplatní sa len pri prechode do stavu, čiže na nové zatvorenia.
  Staré zatvorené úlohy s nižším % zostávajú, ako sú.
- **Nespustí sa znova pri ďalšom uložení.** Už zatvorenej úlohe sa dá % kedykoľvek znížiť
  ručne a plugin to neprepíše — reaguje len na zmenu stavu.
- **Nesiaha na rodičovské úlohy s odvodeným %.** Keď je `Setting.parent_issue_done_ratio`
  nastavené na `derived`, hodnotu počíta jadro z podúloh a zápis by sa aj tak stratil.
- **Nerobí nič v režime „% Done podľa stavu".** Tam si hodnotu riadi jadro samo.

Zmena sa zapisuje do histórie úlohy ako bežná zmena poľa („% Done zmenené z 0 na 100"),
takže je dohľadateľné, že sa stala.

## Testy

```sh
docker compose exec -T --user redmine -e SECRET_KEY_BASE=... redmine \
  bin/rails runner -e production plugins/redmine_done_on_close/extra/selftest.rb
```

8 kontrol. Beží proti živej databáze, ale celý test je v transakcii, ktorá sa na konci
zahodí — po sebe nenechá ani stopu.

## Poznámka k inštalácii

Patch na `Issue` sa aplikuje priamo v `init.rb`, **nie v `to_prepare`** — ten sa
v produkčnom režime nespustí a patch by ticho nikdy nenabehol.

## Licencia

Copyright (C) 2026 Martin Kopáč

GPL-2.0-or-later, rovnako ako Redmine — viď [LICENSE](LICENSE).
