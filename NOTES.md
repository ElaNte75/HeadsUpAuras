# NOTES.md — HeadsUpAuras (retail + Forever)

## Τι είναι το project

Το WoW addon **HeadsUpAuras** (v1.4): δείχνει το «πάτησέ το τώρα» εικονίδιο τη
στιγμή που χρειάζεται, με συνθήκες που ορίζει ο χρήστης (health, resources,
cooldowns, empowered abilities, combat state κ.ά.).

**Στόχος:** ΕΝΑ addon που τρέχει ΚΑΙ σε retail (interface 12.x) ΚΑΙ σε WoW Forever
(interface 16001, game type `forever`/`camelot`, σύγχρονο Midnight API με «secret
values»). Ο χρήστης δεν θέλει να συντηρεί δύο addons.

**Πού δουλεύουμε:** ο χρήστης παίζει Forever → η δουλειά γίνεται στον φάκελο
`_forever_\Interface\AddOns\HeadsUpAuras`. Το αντίγραφο στο `_retail_\...\HeadsUpAuras`
ΔΕΝ πειράζεται (δουλεύει όπως είναι). Κοινές αλλαγές μόνο με ρητή συμφωνία.

## Κανόνας για κάθε αλλαγή (απόφαση χρήστη 7/11/2026)

Κάθε αλλαγή είναι **retail-only**, **forever-only** ή **κοινή**. Πριν κάθε αλλαγή
επιβεβαιώνουμε σε ποια ανήκει. Αυτή τη στιγμή: όλα γίνονται στο Forever· ό,τι
αγγίζει και τα δύο μπαίνει με ρητή συμφωνία.

## Τρόπος δουλειάς (προτίμηση χρήστη, 7/11)

- Ο χρήστης παίζει όσο εγώ δουλεύω· ΔΕΝ γράφουμε στο chat του παιχνιδιού. Για πληροφορίες
  χρησιμοποιούμε καταγραφικό (`ForeverProbe.lua`): ο χρήστης κάνει /reload και διαβάζω
  `_forever_\WTF\Account\<ACCOUNT>\SavedVariables\HeadsUpAuras.lua`
  (`HeadsUpAurasDB.probe`, `.log`, `.errors`).
- Δεν υπάρχει εργαλείο ελέγχου σύνταξης Lua στο PC → οι αλλαγές ελέγχονται μόνο με
  /reload στο παιχνίδι (Lua error ⇒ `HeadsUpAurasDB.errors`).

## Τι έγινε (7/11) — όλα δοκιμασμένα από τον χρήστη εκτός αν λέει αλλιώς

### Φόρτωση / Forever port
- `HeadsUpAuras.toc` (dual: 120107, 120105, 120100, 16001) + `HeadsUpAuras_Forever.toc`
  (μόνο 16001). Ο κώδικας ήταν ήδη θωρακισμένος για secret values.
- Spec API: στο Forever λείπουν τα `GetSpecialization*` → fallback στο `C_SpecializationInfo`
  (SpecAPI στη Settings, RefreshCurrentSpec στο core). Λειτουργεί.
- Tracker: το `suppressEnabled` είναι υποχρεωτικό για trackers.

### Ευρήματα για το Forever (από ForeverProbe)
- Build 70862, `WOW_PROJECT_ID = 18` (CAMELOT), toc 16001.
- Το **Rockbiter ΔΕΝ είναι aura**: φαίνεται μόνο με το global `GetWeaponEnchantInfo()`
  (12 τιμές: main/off/thrown × has, ms υπόλοιπο, charges, enchantID). Διαβάζεται και
  ΜΕΣΑ σε μάχη. Rockbiter = enchantID 29, spell 8017.
- `UnitAura`/`UnitBuff` δεν υπάρχουν· υπάρχουν `C_UnitAuras.GetAuraDataByIndex`,
  `GetPlayerAuraBySpellID` κ.ά. αλλά **σε μάχη τα auras του player πετάνε error (secret)**.
- Τα cast του player (UNIT_SPELLCAST_SUCCEEDED) διαβάζονται κανονικά, και σε μάχη.
- `C_Secrets` υπάρχει (27 συναρτήσεις), π.χ. `ShouldAurasBeSecret`.

### ImbueWatch (`ImbueWatch.lua`, forever-only) — δουλεύει
- Tracker για weapon imbue ακολουθεί το ΠΡΑΓΜΑΤΙΚΟ imbue (υπόλοιπο χρόνου από το παιχνίδι).
  Mapping spell→enchantID: seed 8017→29 + αυτο-εκμάθηση (`HeadsUpAurasDB.imbues`).
- Dropdown «Show the icon» (`imbueWarn`): όταν χαθεί / 15s / 30s / 1·2·5·10 λεπτά πριν
  λήξει. Επιβεβαιώθηκε in-game (8/11): «όταν χαθεί» και «1 λεπτό πριν λήξει». Τα υπόλοιπα χρονικά δεν δοκιμάστηκαν ξεχωριστά αλλά χρησιμοποιούν τον ίδιο μηχανισμό.
- Αλλαγές στον core (no-op στο retail): `HeadsUpAuras_EachIndicator`, `HeadsUpAuras_RefreshAll`,
  `HeadsUpAuras_ImbueOwns` (παράκαμψη «reset ανά target» και clear μετά τη μάχη).

### Wizard / οπτικά (Settings.lua, UI.lua, core)
- Round icon: W γκρι, το τελευταίο box = διάμετρος (Ø). Νέα `when` / `unitFn` στα controls.
- Rim round icon: πάχος 1/2/3 = ΠΟΣΟ ΑΠΛΩΝΕΤΑΙ («έκρηξη», ακανόνιστο σχήμα, έντονο δίπλα
  στην εικόνα και ξεθωριάζει προς τα έξω). Αρχεία `Media/fx/rim_w1-3.tga`, `aura_1-3.tga`
  (παραγμένα με Python μία φορά). Μεγέθη: `RIM_SIZE` 1.4/1.7/2.0, `AURA_SIZE` 1.5/1.85/2.25.
- Rim color: **Gold** (default) / **Follow the class** (RAID_CLASS_COLORS) / **Custom**.
  `RimTint(cfg)`. Το χρώμα ισχύει και για το glow. Παλιό `auto` → `gold` στο load.
- Εφέ round: **Glow** (άβρα αναβοσβήνει + το rim σβήνει/ανάβει μαζί), **Pulse** (χωρίς rim/άβρα,
  μόνο το εικονίδιο «αναπνέει»), **Glow + pulse** (`both`, μόνο round). Τετράγωνο: όπως πριν.
- **Pulse**: το animation του παιχνιδιού πηδούσε. Τελική λύση (επιβεβαιωμένη, τετράγωνο και
  round): `MakeBreath` = χειροκίνητο ημίτονο 1→0.92→1 σε 1s (OnUpdate) + `NoSnap`
  (`SetSnapToPixelGrid(false)`) στην εικόνα/μάσκα.
- Tooltip σε κομμένα items του ανοιχτού dropdown + `tip` ανά επιλογή (Choice).
- Specialization χωρίς specs (low level): γκρι item «All specs (no specialization yet)».
- Για imbue trackers η κάρτα «After a cast» κρύβει τα δευτερόλεπτα και το «Start over on a
  new target».

## ΕΚΚΡΕΜΟΤΗΤΕΣ — τι μένει

### Να ελέγξει ο χρήστης (in-game, με /reload)
1. Dropdown «Show the icon» του imbue (π.χ. «15 seconds before it ends») — ανάβει στην ώρα του;
2. Rim color «Follow the class» και «Custom»· rim πάχη 1/2/3 με το Glow και το Pulse.
3. Άλλα imbues (Flametongue, Windfury): αυτο-εκμάθηση spell→enchant, και off-hand όπλο.
4. Το αρχικό τεστ του port: εικονίδια με συνθήκες health/power/cooldowns σε μάχη χωρίς Lua errors
   (`/console scriptErrors 1`).

### Σε εξέλιξη (session 2): παρακολούθηση buffs σε μάχη
Απόφαση: πρώτα δοκιμή «Γ» (τι διαβάζεται σε μάχη), μετά υλοποίηση Α (cast+γνωστή διάρκεια)
+ Β (διόρθωση εκτός μάχης). ΓΕΝΙΚΟ για όλους τους χαρακτήρες/κλάσεις (ο χαρακτήρας είναι μόνο για τεστ).
Προστέθηκε στο `ForeverProbe.lua` η `Deep()` (γραμμές `[deep]` και `[auraevent]` στο `probe`):
δοκιμάζει GetPlayerAuraBySpellID / GetAuraDataBySpellName / GetSpellAuraSecrecy για κάθε buff που
είδε εκτός μάχης. Ο χρήστης: βάζει buffs, μπαίνει σε μάχη, /reload → διαβάζω το SavedVariables.
Εύρημα: το σφάλμα λέει «secret while tainted by HeadsUpAuras» (ίσως μετράει το taint του addon).
**Αποτέλεσμα Γ (7/11):** εκτός μάχης όλα διαβάζονται (bySpellID/byName δίνουν διάρκεια/λήξη). ΣΕ ΜΑΧΗ:
bySpellID/byName επιστρέφουν nil (ακόμα κι όταν το buff υπάρχει, π.χ. Mark of the Wild), GetUnitAuras
και auras του target → error. `GetSpellAuraSecrecy` = 2 για όλα. UNIT_AURA event έρχεται. ⇒ τίποτα δεν
διαβάζεται σε μάχη· επόμενο βήμα Α (cast + διάρκεια) + Β (διόρθωση εκτός μάχης).

### Ranks (8/11) — διορθώθηκε, επιβεβαιώθηκε in-game (Rockbiter r2)
Στο Forever τα spells έχουν ranks: κάθε rank = άλλο spell id ΚΑΙ άλλο enchant (Rockbiter r1 8017→29,
r2 8018→6). Ο tracker φτιαγμένος για r1 δεν αναγνώριζε το r2. Τώρα το `ImbueWatch.lua` (`EnchantsFor`)
δέχεται τα enchants ΟΛΩΝ των spells με το ίδιο ΟΝΟΜΑ (μαθαίνονται αυτόματα με το πρώτο cast κάθε rank).
### BuffWatch.lua (8/11) — ΥΛΟΠΟΙΗΘΗΚΕ, ΑΔΟΚΙΜΑΣΤΟ, forever-only
Αποτέλεσμα probe: σε μάχη το UNIT_AURA έρχεται αλλά ΟΛΑ είναι secret (ποιο buff, updated/removed λίστες) →
δεν ξέρουμε ποιο buff άλλαξε. Εκτός μάχης όλα ορατά (LS μπήκε 3 stk, βγήκε 1).
Υλοποίηση: tracker buff πάνω σου (αυτο-εκμάθηση: buff ίδιου ονόματος πάνω σου → `HeadsUpAurasDB.buffs[name]
= {dur, stk}`). Cast → timer = μαθημένη διάρκεια ή από περιγραφή («Lasts 10 min»). Εκτός μάχης (ticker 3s,
UNIT_AURA, τέλος μάχης, login) → διόρθωση από το πραγματικό buff. Επιλογές wizard: «Show the icon» (`imbueWarn`,
κοινό με imbue) και «Also show at N stacks or fewer» (`buffStacks`). Hooks: core (reset target/τέλος μάχης
αγνοούν `HeadsUpAuras_BuffOwns`), Settings `BuildAfterCastCard` (`isBuff`). Buff με άλλο όνομα από το spell
(π.χ. Stoneskin Totem → «Stoneskin») δεν αναγνωρίζεται → μένει στον απλό timer.

Επιβεβαιώθηκε: μετά το πρώτο cast εκτός μάχης ο tracker LS δείχνει τις νέες επιλογές. Προστέθηκε σημείωση στην
κάρτα «After a cast» (Forever, tracker μη μαθημένος): «Cast it once out of combat...». Εκκρεμεί τεστ σε μάχη.

### Εναλλακτικά imbues/buffs + δύο εικονίδια στο ίδιο σημείο (8/11) — ΑΔΟΚΙΜΑΣΤΟ
- **«Or any of these»** (πρώην «Also counts», `alsoCounts = { [όνομα ability] = true }`, ανά ΟΝΟΜΑ → κάθε rank): στην κάρτα «After a cast»
  για imbue/buff trackers. Το εικονίδιο ανάβει μόνο όταν ΚΑΝΕΝΑ δεν υπάρχει (ImbueWatch `WantedFor`,
  BuffWatch: ακολουθεί αυτό που κρατάει περισσότερο· cast εναλλακτικού ξεκινά timer σε μάχη).
- Trackers που ακολουθούν πραγματικό imbue/buff: οι συνθήκες στόχου (εχθρός/ζωντανός κ.λπ.) ΔΕΝ μετράνε
  (`ReadableConditionsMet`· το crowd μετράει). Αιτία: ο LS tracker είχε tgtHostile/enemyAlive ενεργά.
- **ΣΗΜΑΝΤΙΚΟ bug που βρέθηκε:** τα `buffStacks`, `hideDead` έλειπαν από το `KEYS` του core → δεν
  αποθηκεύονταν (το hideDead δούλευε μόνο ως default). Προστέθηκαν μαζί με `alsoCounts` (+ copy/dirty).
- Probe: γραμμές `[vis]` (κάθε 0.5s, μόνο σε αλλαγή): ανά εικονίδιο shown/alpha/hide/imbue/buff — για το θέμα
  «δύο εικονίδια στο ίδιο σημείο: όταν καλύπτω το ένα χάνεται και το άλλο». Αναμένεται τεστ χρήστη.

### Specs χωρίς ονόματα + κείμενο «Important info» (10/11) — ΑΔΟΚΙΜΑΣΤΟ, ΚΟΙΝΟ
- Η λίστα Specializations έδειχνε κουτάκια χωρίς ονόματα (retail ΚΑΙ Forever). Αιτία: δικό μας bug από το port
  (`ClassSpecs`: «local id, name = infoFn and infoFn(i)» κρατούσε μόνο το id). Διορθώθηκε.
- Σημείωση «Tip: a buff on you or a weapon imbue? Cast it once...» στην κάρτα «After a cast» (tracker που δεν
  έχει μάθει ακόμα): ισχύει πλέον και στο retail, καλύπτει και imbues. Ο χρήστης θέλει να «διαφημίζει» την εκμάθηση.
- Κάρτα «After a cast»: οι Notes (UI.lua `CardMethods:Note`) μπαίνουν πλέον στο `TrackRow` → ανεβαίνουν όταν
  κρύβονται γραμμές (πριν έμενε κενό και η σημείωση έβγαινε έξω από την κάρτα). ΚΟΙΝΟ, επηρεάζει όλες τις Notes.
- Κενό ΑΝΑΜΕΣΑ στις κάρτες: οι κάρτες είχαν σταθερή θέση· τώρα `page:Restack()` (UI.lua) τις ξαναστοιβάζει όταν
  μια κάρτα μικραίνει (καλείται από `Relayout`). ΚΟΙΝΟ, όλες οι σελίδες του wizard.
- Notes με `rows = N` (UI.lua): σε πολλές γραμμές με αναδίπλωση· η σημείωση της «After a cast» έχει 2.
- «Also show at N stacks» φαίνεται μόνο αν το buff έχει δει >1 stack (ή έχει ήδη ρυθμιστεί)· πριν φαινόταν και
  στο Skyfury (retail) που δεν έχει stacks.
- «Or any of these»: μένει ελεύθερη επιλογή του χρήστη (όλα τα abilities)· εξηγείται στη σημείωση της κάρτας
  (`ANY_NOTE`). Απόφαση χρήστη: όχι περιορισμός της λίστας.
- Ετικέτες: «Show the icon» (imbueWarn) → «Warn me»· «Show it» (trackShow): «while it is on» / «while it is missing».
- «Important info»: στο Forever άλλο κείμενο (`INFO_PARAGRAPHS`, Forever: buffs από cast + έλεγχος μετά τη μάχη,
  imbues διαβάζονται και σε μάχη). Το παράθυρο μεγαλώνει με το κείμενο.

### Χρόνος από την περιγραφή: λεπτά/ώρες (10/11) — ΑΔΟΚΙΜΑΣΤΟ, ΚΟΙΝΟ
`SuggestedDuration` (Settings) καταλαβαίνει sec/min/hour(s)/hr(s) («Lasts 1 hour» → 3600). Όριο `MAX_HIDE` =
3 ώρες (10800 s, απόφαση χρήστη) αντί για 300· το κουτάκι «hide for» δέχεται έως 5 ψηφία. Ισχύει όταν
διαλέγεται το ability (υπάρχοντες trackers κρατάνε τον παλιό χρόνο). Αφορμή: στο retail ο Flametongue tracker
έβγαζε 10 s. **ImbueWatch + BuffWatch τρέχουν πλέον ΚΑΙ στο retail** (απόφαση χρήστη 10/11, ΑΔΟΚΙΜΑΣΤΟ εκεί). Το BuffWatch
μόνο για kind=="tracker". Το ForeverRanks μένει forever-only. Το `ForeverProbe.lua` τρέχει ΠΡΟΣΩΡΙΝΑ και στο
retail (`HeadsUpAurasDB.probe` στο SavedVariables του `_retail_`) — να ξαναμπεί το gate στο καθάρισμα.
Ο χρήστης αντιγράφει μόνος του τον φάκελο Forever → retail για δοκιμές.
Στο retail έβγαζε πάλι 10 s: πιθανή αιτία ο κωδικός πληθυντικού «|4hour:hrs;» στις περιγραφές → αφαιρείται
(Settings `SuggestedDuration`, BuffWatch `DescDuration`). ΠΡΟΣΩΡΙΝΟ log στο `SelectAbility` («suggested=… desc=…»).

### «Hide while I am dead» (8/11) — επιβεβαιώθηκε in-game (Forever), ΚΟΙΝΟ (retail+Forever)
Situation → κάρτα «When it shows»: `hideDead` (default ON· παλιά auras χωρίς τιμή = ON, `~= false`).
Core: έλεγχος `UnitIsDeadOrGhost("player")` στην αρχή του `ShowRulesAllow` + events PLAYER_DEAD/ALIVE/UNGHOST
(με pcall). Ανέβηκε στο GitHub main: commit `2cdfb5a`.

### Glow πάνω από τον χάρτη (8/11) — διορθώθηκε, επιβεβαιώθηκε in-game
Το `GL` (glow) ήταν ένα strata ΠΑΝΩ από το εικονίδιο (`EFFECT_STRATA`) → layer 3: εικονίδιο MEDIUM, glow HIGH =
ίδιο με τον χάρτη. Τώρα: ίδιο strata με το εικονίδιο + frame level +20 (2 σημεία στο core). Το `EFFECT_STRATA`
έμεινε αχρησιμοποίητο (καθάρισμα). **Το ίδιο bug υπάρχει στο αντίγραφο του retail** (δεν πειράχτηκε).

### Buff watcher με stacks (8/11) — έρευνα
Στόχος (ΓΕΝΙΚΟ για κάθε buff, κάθε κλάση): tracker buff με διάρκεια αυτόματα + «όταν χαθεί / Χ πριν λήξει»
(όπως imbue) + stacks (π.χ. Lightning Shield 3 χρεώσεις). Ιδέα: εκτός μάχης μαθαίνουμε το auraInstanceID του
buff· σε μάχη το UNIT_AURA ίσως λέει ποιο id άλλαξε/αφαιρέθηκε. Probe: γραμμές `[auracombat]` (added/updated/
removed + byInstance) και «known instances» στο `[combat] entered`. CombatLogGetCurrentEventInfo = nil στο Forever.
Τεστ χρήστη: /reload, Lightning Shield, μάχη μέχρι να φύγει, /reload.

### ForeverRanks.lua (8/11) — επιβεβαιώθηκε η «μία φορά» στη λίστα, forever-only (στο retail δεν ορίζει τίποτα → ίδια συμπεριφορά)
- Λίστες abilities: μία φορά κάθε ability (το υψηλότερο rank, από `subName` «Rank N»).
- Cast οποιουδήποτε rank ξεκινά το timer ενός aura φτιαγμένου με άλλο rank (core, ίδιο όνομα).
- Λίστα Tracker: μόνο abilities που η περιγραφή τους (`C_Spell.GetSpellDescription`) έχει χρόνο
  («lasts», «N sec/min/hour»). Χωρίς περιγραφή → μένει. Γνωστή ατέλεια: Earth Shock («2 sec») μένει.
- Hooks (κλήσεις μόνο αν υπάρχει η συνάρτηση): Settings `GetAbilities`, `KindAbilities`, `selected`
  του dropdown· core cast matching. Πρόταση για αργότερα: αυτόματη διάρκεια από την περιγραφή.

### Συμφωνημένα, δεν έγιναν
- Tracking: επιλογή «The effect is on: Me / The enemy» (για abilities χωρίς γνωστό side).

### Προτάσεις (θέλουν συμφωνία/απόφαση)
1. **Αρχείο «Συμβατότητας»**: ένα σημείο που ανιχνεύει Forever/retail (WOW_PROJECT_ID 18 ή
   build 16000–20000) και μαζεύει τις διαφορές (spec API, imbue κ.λπ.), ώστε ένα addon να
   κάνει διαφορετικά πράγματα σε κάθε παιχνίδι. Μετά: αφαίρεση του `HeadsUpAuras_Forever.toc`
   (το κύριο toc έχει ήδη και τα δύο interface).
2. **KnownDurations για Forever**: ο πίνακας είναι από retail, το Forever έχει άλλα
   ονόματα/διάρκειες (Rockbiter 60 λεπτά δεν υπάρχει). Να παραχθεί/συμπληρωθεί.
3. **Buff watcher για κανονικά buffs** (όχι imbue): τα auras του player δεν διαβάζονται σε μάχη
   (secret). Έξω από μάχη διαβάζονται. Προτείνεται: cast + γνωστή διάρκεια + έλεγχος εκτός μάχης,
   όπως ήδη κάνει ο tracker· χρειάζεται συζήτηση πριν υλοποιηθεί.
4. **Μέγεθος αρχείων**: `HeadsUpAuras.lua` 4082 γραμμές, `Settings.lua` 3796, `UI.lua` 1198 —
   πολύ πάνω από τον στόχο 600–700. Πρόταση: διαχωρισμός σε modules (με συμφωνία).
5. **Εργαλείο ελέγχου σύνταξης Lua** (π.χ. luac/luacheck) στο PC, ώστε να πιάνονται λάθη πριν
   το /reload.
6. **Καθάρισμα στο τέλος:** `ForeverProbe.lua` (+ γραμμές στα 2 toc), οι κλήσεις
   `HeadsUpAuras_Log` και τα `HeadsUpAurasDB.log/probe` στο SavedVariables· αχρησιμοποίητα:
   `Media/fx/rim_gold.tga`, `RIM_BY_STYLE`/`RIM_GOLD` στον core.
7. **GitHub (8/11):** repo `ElaNte75/HeadsUpAuras` (δημόσιο), τοπικός κλώνος
   `C:\Users\ElaNte\Desktop\Projects\HeadsUp_Addon` (τα αρχεία του addon στον υποφάκελο `HeadsUpAuras/`).
   Commit `2930a5d` στο **main** (απόφαση χρήστη): όλες οι αλλαγές του Forever + `NOTES.md` στη ρίζα
   (με `<ACCOUNT>` αντί για το όνομα λογαριασμού). ΧΩΡΙΣ `ForeverProbe.lua` (και χωρίς τη γραμμή του στα toc).
   Το `AGENTS.md` του repo (τεχνικό) δεν αντικαταστάθηκε. Ο τοπικός κλώνος ΔΕΝ ενημερώθηκε (είχε δικές του
   αλλαγές σε `scripts/ship.ps1`, `tools/make_fx.py` που δεν πειράχτηκαν) → χρειάζεται `git pull` με προσοχή.
   Έλεγχος σύνταξης Lua υπάρχει: `py` + `lupa` (βλ. AGENTS.md του repo) — χρησιμοποιήθηκε, όλα OK.
   Οι κοινές οπτικές αλλαγές (rim, pulse, glow strata) ισχύουν και στο retail από το GitHub, αδοκίμαστες εκεί.

### Πρόταση για το επόμενο session
Νέο session (το τρέχον έχει μεγάλο context). Μοντέλο: Sonnet για μικρές διορθώσεις και
δοκιμές· Opus για σχεδιασμό (αρχείο Συμβατότητας, buff watcher, διαχωρισμός αρχείων).
Σειρά: (1) τεστ του χρήστη στα παραπάνω, (2) Tracking Me/Enemy, (3) KnownDurations Forever,
(4) αρχείο Συμβατότητας, (5) καθάρισμα debug.

## Χάρτης αρχείων

- `HeadsUpAuras.toc` — κύριο toc (dual interface retail + Forever).
- `HeadsUpAuras_Forever.toc` — flavored toc μόνο για Forever (περιττό αν γίνει το αρχείο Συμβατότητας).
- `HeadsUpAuras.lua` (4082 γρ.) — πυρήνας: events, conditions, indicators/faces, εφέ (rim, glow,
  pulse), secret-value guards.
- `Settings.lua` (3796) — ρυθμίσεις/wizard· `UI.lua` (1198) — βοηθητικό UI (controls, dropdown, tooltips).
- `ImbueWatch.lua` — forever-only: weapon imbue tracker (δέχεται όλα τα ranks).
- `ForeverRanks.lua` — forever-only: ranks = ένα ability, φίλτρο λίστας Tracker.
- `BuffWatch.lua` — forever-only: tracker buff πάνω σου (πραγματική διάρκεια, διόρθωση εκτός μάχης, stacks).
- `ForeverProbe.lua` (267) — forever-only, ΠΡΟΣΩΡΙΝΟ καταγραφικό (`HeadsUpAurasDB.probe`).
- `Minimap.lua`, `KeyText.lua` — minimap icon, keybind text.
- `KnownDurations.lua`, `KnownGlows.lua` — δεδομένα (retail-derived· εξαιρούνται του ορίου μεγέθους).
- `Media/fx/` — εικόνες εφέ (rim_w1-3, aura_1-3, κ.ά.), `Media/`, `Sounds/`.
- `AGENTS.md`, `NOTES.md` — εσωτερικά αρχεία εργασίας (ΔΕΝ ανεβαίνουν στο GitHub).
- SavedVariables: `HeadsUpAurasDB` (στο `_forever_\WTF\Account\<ACCOUNT>\SavedVariables\`).
