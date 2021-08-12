---
title: "Ledger - Finanse dla geeków"
draft: true
# cover:
#   image: "aws-badges.png"
#   alt: "Piotr Belina AWS Certifications Badges"
ShowToc: true
date: 2021-08-08 20:00:00
---
## Księgowość dla geeków - Alternatywa dla YNAB
Przez kilka lat używałem do prowadzenia budżetu aplikacji YNAB 4 w wersji na komputer. Był to dobry początek, jednak sporo elementów przeszkadzało mi w samej aplikacji.

## Moje wymagania
 Po jakimś czasie odkryłem swoje wymagania i oto one.

### Szybkie działanie aplikacji
YNAB 4 nie grzeszy wydajnością. W momencie kiedy posiadamy sporo transakcji przełączanie się między widokami potrafi trwać kilka czy kilkanaście sekund. U mnie powoduje to niechęć do korzystania z aplikacji a w konsekwencji nieregularność w prowadzeniu budżetu domowego.

Z YNAB 4 jest również taki problem, że jest aplikacją nierozwijaną. I tak jak nie przeszkadzał mi specjalnie brak nowych funkcjonalności to fakt, że wraz z aktualizacją MacOS YNAB miał przestać działać, frustrował mnie. Całe szczęście jest opcja na update Maca i zachowanie działania YNAB: więcej do przeczytania [tutaj](https://gitlab.com/bradleymiller/Y64). 

### Obsługa wielu walut
W YNAB wybieramy walutę przy tworzeniu budżetu i potem widzimy ją przy transakcjach. Jednak nie ma możliwości wprowadzenia w jednym budżecie transakcji w kilku walutach. Jedyna opcja to tworzeniu budżetu na każdą walutę osobno. Jednak jest to dość ułomne rozwiązanie, bo nie możemy utworzyć bilansu uwzględniającego konta w różnych walutach. 

Teraz nie jest to kluczowa funkcjonalność dla mnie, ale kiedy mieszkałem za granicą i miałem budżet w złotówkach oraz w € była to duża dokuczliwość. 

### Śledzenie wartości nieruchomości, inwestycji etc.
W YNAB można co prawda dodać jakiś zasób (nieruchomość, samochód etc.) niemniej mamy możliwości śledzenia wartości jedynie w walucie budżetu. Nie możemy dodać 20 akcji spółki albo 30 jednostek funduszu, musimy od razu wycenić ile jest to warte w naszej walucie. 

### Import z plików CSV
YNAB pozwala na import z CSV, ale musimy przygotować dość skrupulatnie taki plik. YNAB jest dość wymagający pod kątem formatu CSV. Napisałem narzędzie pomagające przekształcanie plików CSV uzyskanych z banku, ale nie jest to zbyt wygodny proces. 

### Generowanie bilansu
Od kilku lat co miesiąc tworzę w arkuszu kalkulacyjnym nową kolumnę i spisuję stan kont. Śledzę aktywa i pasywa i dostaję wartość netto. W YNAB jest również taki wykres, ale ze względu na brak możliwości śledzenia kont w różnych walutach lub kont inwestycyjnych, muszę się wspomagać arkuszem. Oczywiście chętnie pozbyłbym się takiego podwójnego systemu.

## Plain text accounting - księgowość w pliku tekstowym
O plain text accounting nie znalazłem jeszcze ani jednego artykułu w polskim internecie. Jest to dla mnie duże zaskoczenie. Dlatego też chciałbym podzielić się moim odkryciem i rozpowszechnić je. 

### Czym jest księgowość w pliku tekstowym?
To prowadzenie budżetu w zwykłym pliku z odpowiednim formatowaniem i używanie programów do analizowania tego pliku. W 2003 roku John Wiegley napisał program raportujący [Ledger](https://www.ledger-cli.org/) działający w linii komend oraz opisał format danych Ledger pozwalający korzystać z księgowania wraz regułą podwójnego zapisu. W kolejnych latach powstał [hledger](https://hledger.org/), [Beancount](https://github.com/beancount/beancount) oraz [inne klony](https://plaintextaccounting.org/#plain-text-accounting-apps). 

### Okej, nic mi to nie mówi. Pokaż jak działa
Rzeczywiście, może to trochę suchy opis czym jest Ledger i księgowość w pliku tekstowym (KPT). Żeby zacząć korzystać z Ledgera, tworzymy plik i dodajemy nasze transakcje. Tak wygląda pojedynczą transakcja. 
```ledger
2021-04-27 Stacja benzynowa X
  Wydatki:Auto:Paliwo       100,00 PLN
  Aktywa:Konto ROR Bank 1  -100,00 PLN
```
Możemy dla tego pliku utworzyć bilans.
```
❯ ledger -f przyklad.ledger balance
         -100,00 PLN  Aktywa:Konto ROR Bank 1
          100,00 PLN  Wydatki:Auto:Paliwo
--------------------
                   0
```
Albo sprawdzić historię konkretnego konta.
```
❯ ledger -f przyklad.ledger register Wydatki
21-Apr-27 Stacja benzynowa X    Wydatki:Auto:Paliwo   100,00 PLN  100,00 PLN
```
## Przykładowy plik
```
; -*- ledger -*-

= /^Przychody/
  (Należności:Darowizny)                    0.12

;~ Monthly
;  Aktywa:ROR                     500.00 PLN
;  Przychody:Pensja

;~ Monthly
;   Wydatki:Jedzenie   100 PLN
;   Aktywa

2010/12/01 * ROR saldo
  Aktywa:ROR                   1,000.00 PLN
  Kapitał własny:Saldo początkowe

2010/12/20 * Organic Co-op
  Wydatki:Jedzenie:Spożywcze             37.50 PLN  ; [=2011/01/01]
  Wydatki:Jedzenie:Spożywcze             37.50 PLN  ; [=2011/02/01]
  Wydatki:Jedzenie:Spożywcze             37.50 PLN  ; [=2011/03/01]
  Wydatki:Jedzenie:Spożywcze             37.50 PLN  ; [=2011/04/01]
  Wydatki:Jedzenie:Spożywcze             37.50 PLN  ; [=2011/05/01]
  Wydatki:Jedzenie:Spożywcze             37.50 PLN  ; [=2011/06/01]
  Aktywa:ROR                   -225.00 PLN 

2010/12/28=2011/01/01 Acme Mortgage
  Należności:Kredyt hipoteczny:Kapitał     200.00 PLN
  Wydatki:Odsetki:Kredyt hipoteczny       500.00 PLN
  Aktywa:ROR                  -700.00 PLN

2011/01/02 Grocery Store
  Wydatki:Jedzenie:Spożywcze             65.00 PLN
  Aktywa:ROR

2011/01/05 Employer
  Aktywa:ROR                   2000.00 PLN
  Przychody:Pensja

2011/01/14 Bank
  ; Regular monthly Oszczędnościowe transfer
  Aktywa:Oszczędnościowe                     300.00 PLN
  Aktywa:ROR

2011/01/19 Grocery Store
  Wydatki:Jedzenie:Spożywcze             44.00 PLN ; hastag: not block
  Aktywa:ROR

2011/01/25 Bank
  ; Transfer to cover car purchase
  Aktywa:ROR                  5,500.00 PLN
  Aktywa:Oszczędnościowe
  ; :nobudget:

apply tag hastag: true
apply tag nestedtag: true
2011/01/25 Tom's Used Cars
  Wydatki:Auto                    5,500.00 PLN
  ; :nobudget:
  Aktywa:ROR

2011/01/27 Księgarnia
  Wydatki:Książki                       20.00 PLN
  Należności:MasterCard
end tag
2011/12/01 Sprzedaż
  Aktywa:ROR:Firmowe            30.00 PLN
  Przychody:Sprzedaż
end tag

```

[GitHub - faressoft/terminalizer: 🦄 Record your terminal and generate animated gif images or share a web player](https://github.com/faressoft/terminalizer)