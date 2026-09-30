# AAA++-visual redesign — folder, asset-family, and promotion matrix

Päivä: 2026-09-16  
Kohde: `C:\Users\heikk\Desktop\Claude\gpt_peli`, Godot 4.7 Mobile, 2D, 480 x 270 landscape

Tämä matriisi on käytännön jatkosuunnitelma syväauditille. Se ei väitä, että
31 404 lähdetiedostoa olisi käsin hyväksytty; niiden yksilöllinen hash-,
formaatti-, rooli- ja provenance-rivi on `artifacts/asset_audit`-ledgereissä.
Sen sijaan se sitoo jokaisen runtimeen vaikuttavan folder-perheen, sen
nykyisen kuvasopimuksen ja seuraavan hyväksyttävän parannusreitin samaan
päätöstaulukkoon.

## A. Vault- ja export-raja

| Lähde/folder | Audit-disposition | Runtime-disposition | Seuraava sallittu teko |
|---|---|---|---|
| `Addons/**` (31 404 fyysistä tiedostoa, 4 684 auditoitua arkistojäsentä) | Jokainen tiedosto hashattu; sisältö/rooli/lisenssisignaali on ledgerissä | Ei suoraa runtime-referenssiä pelkän saatavuuden perusteella | Valitse vain lisensoitu semanttinen aukko, tee offline-bake ja läpäise kaikki portit |
| `assets/2d/_source_imports/**` | Säilytetty provenance- ja vertailulähteenä | Ei live-scene- tai runtime-manifestireferenssiä auditissa | Ei suoraa käyttöä; säilytä alkuperäinen attribution, tee vain uusi johdettu slice |
| `assets/runtime_asset_manifest.json` | Live-closure on erikseen tarkistettu | 12 suoraa reviewed-promoottia; johdetuilla atlas-perheillä omat manifestit | Lisää entry vain hyväksytyn provenance-, bake-, hash- ja render-portin jälkeen |
| `artifacts/**` | Audit- ja render-evidenssi | Ei export-sisältöä | Säilytä myös hylätyt kokeet; ne estävät samojen visuaalisten virheiden toiston |

## B. Pelaajalle näkyvät 2D-perheet

| Folder/perhe | Nykyinen sopimus | Nykyinen päätös | Premium-AAA++ seuraava askel | Ei-neuvoteltava portti |
|---|---|---|---|---|
| `assets/2d/characters/**`, `scenes/characters/**` | Start menu käyttää Heikki/Shane-topdown-kuvia; legacy fallback on säilytetty | Safe-area ja valintahierarkia hyväksytty, raaka muotokuvaart ei korvattu | Tee kaksi hyväksyttyä, matalan liikkeen idle-portrait/diorama-bakea vain jos in-world body identity pysyy samana | 44 px targetit, launch/LAN-flow, safe-inset, no clipping |
| `assets/2d/actors/frames/**`, `sheets/**`, `scenes/**` hero | 8-suuntaiset idle/run/shoot/hit/gather/death-baket; keyline+rim seuraa tarkkaa framea | Luettavuusparannus hyväksytty, ei vielä full sprite replacement | Laadi authoring brief: suurempi vartalomassa, erottuva ase-/reppu-siluetti, action line ja 8-suuntaiset pivotit | 0.38-color+grayscale, remote camera, death/respawn, no collision/RPC change |
| `assets/2d/actors/frames/**`, `sheets/**`, `scenes/**` normal zombies | Walker, rat swarm, static walker, scrap shield ovat omia body/clip-perheitä | Pysyvä idle-marker poistettu; aktiiviset combat/status-cuet säilytetty | Body-material matrix: tunnistettava pää/torso/ase/armor-read ilman rengasta jokaiselle neljälle | 0.38 color/grayscale, horde density, direction/action/death frame sync |
| `assets/2d/actors/frames/**`, `sheets/**`, `scenes/**` bosses | Goliath, Carrier, Splitter, Overlord ovat omia boss-clippejä | Same-frame body-rim on turvallinen mutta **HOLD** pienille bosseille | Kalibroi ensin character-relative reaalinen body mass ja lähde-bake/repaint brief; älä kasvata rim-arvoa sokkona | Jokainen 4 bossia lukee harmaasävyssä ennen idle/active markeria |
| `assets/2d/structures/**`, `src/tactical/placed_structure_2d.gd` | 8 erillistä Blender-authored siluettia; ready/tracking/rearming/disabled state language | Hyväksytty focused-portissa | Kuvaa trigger/spent/recovery tiheässä horde-tilanteessa; tee vain event-owner VFX jos signaali ei riitä | 64 px placement, collision/pathing, host snapshot, Android budget |
| `assets/2d/effects/**`, `src/feedback/vfx_director.gd` | Pooled CPU-particles; rauhalliset ambientit eivät varasta combat-poolia | Death-fragment sekä kontrolloitu projectile→hit-body muzzle/impact -hierarkia hyväksytty artifact-portissa | Vahvista tiheässä oikeassa combatissa ja Androidilla; älä nosta efektejä ilman uutta omistaja-porttia | Owner-relative peak+late, color+grayscale, no horde allocation, no snapshot change |
| `assets/2d/resources/**` | Wood/Metal/Tech SVG:t, selkeä resurssikolmikko | Ei kriittistä visuaalista regressiota | Lisää vain kontekstuaalinen pickup/harvest microfeedback VFX-integraatioportin jälkeen | Ei HUD- tai värisekoitusta resurssityyppien välillä |
| `assets/2d/ui/**`, `scenes/ui/**`, `src/ui/**` | 148 x 58 dashboard; build deck 74 px cardit/46 px thumbnailit | Päätöstieto 7 px outlined hyväksytty; tukimekaniikka 6 px | Käy läpi live-world text density sekä näppäimistöfokus erillisenä accessibility-passina | 44 px touch, safe inset, host build path, minimap/touch projection |

## C. World, props, nature, and material families

| Folder/perhe | Nykyinen sopimus | Nykyinen päätös | Premium-AAA++ seuraava askel | Veto-/mittaportti |
|---|---|---|---|---|
| `assets/2d/environment/terrain/**` | Poly Haven terrain atlas + biome blend + road detail | Vakaa pohjamateriaali, ei korvata massana | Lisää vain mikro-kerros, joka ei kilpaile traversability/readabilityn kanssa | 480 x 270 color/grayscale, road clearance, night luma |
| `assets/2d/environment/polyhaven_wild/**` | Wild atlas ruokkii ambient/wilderness/obstacle-ketjua | Nykyinen branch/root Recipe B **REJECTED** | Uusi pieni viileä/neutraali microprop-arrangement offline-bakena; ei samaa isoa korttia | Kaikki 10 wilderness pocketia, card-bounds+32, road >=480, player-relative veto |
| `assets/2d/environment/polyhaven/**`, `local_baked/**` | Camp, city, village, prop-pohjat johdetuissa atlaksissa | Baseline hyväksytty, mutta sommittelullinen variety on avoin | Luo cluster-kit: pieni barrel/toolbox/utility/remainder -ryhmä, jokaiselle funktio/negatiivinen tila | CC0/provenance, alpha/pivot/contact shadow, density/perf capture |
| `assets/2d/environment/polyhaven_district/**` | Hidden Alley -district-atlas, 16 sprite familyä | Baseline, ei massakopiointia | Täydennä vain puuttuva semanttinen katutason funktio (esim. utility/remainder), ei lisää pelkkää noisea | District composition, collision layer, alpha-luma, mobile capture |
| `assets/2d/environment/tiles/**`, `assets/tiles/**` | Ground/nature atlas ja five-plus nature variants | Maaperä toimii substraattina | Lisää ecotone- ja clearing-käsittely vain jos microprop-probe läpäisee | Walkability, tile density, y-sort and no occlusion |
| `src/world/world_background_decor_2d.gd` | 420 propia + rubble/crack/moss, kuusi zone-jakaumaa | Deterministinen, read-only envelope API lisätty auditille | Muuta vain hyväksytyllä new family -slotilla; älä nosta densityä ilman semantic varietyä | Seed determinism, visual envelope, road/player clearances |
| `src/world/world_ambient_scenery_2d.gd`, `world_wilderness_accent_2d.gd` | 10 wilderness pocketia, ambient/backdrop z -4 | Nykyinen natural baseline harva mutta luettava | Hyväksy korkeintaan yksi uusi subordinate family 10-pocket-proben jälkeen | 10/10 coverage, day/night, grayscale, human veto |

## D. Cross-cutting style rules

1. **Body before marker.** Värillinen rengas, health bar, label, light tai
   VFX ei saa olla ensimmäinen tapa tunnistaa hero, zombie, boss, tower tai
   trap neutraliin gameplay-frameen.
2. **Event owns its feedback.** Muzzle on aseessa, impact osumakohdassa,
   death debris rungossa; huippu- ja late-frame arvioidaan ilman testitekstiä.
3. **Nature is subordinate composition, not asset density.** Uusi prop tuo
   korkeintaan yhden uuden luettavan luonnonidean per clearing; jokainen
   muistuttaa ground, road, player ja combat siluetteja.
4. **Warm refuge / cool threat.** Base Core ja eloonjäämisen signalointi voivat
   pitää lämpimän amberin; wilderness, UI secondary ja material debris eivät
   käytä sitä kilpailevana jatkuvana aksenttina.
5. **Offline only before promotion.** Blender MCP ja Poly Haven ovat bake- ja
   source-tutkimusosasto. Runtimeen tulee vain johdettu 2D-artefakti, ei GLTF,
   Blend, raw PBR, Node3D eikä todentamaton Addons-lähde.

## E. Promotion order after current loops

1. Carrier/Splitter character-relative portti on **HOLD**; tee niiden
   provenance-safe offline body-bake/repaint brief ennen uutta runtime-arvoa.
   Muzzle/impact-projektioportti on hyväksytty artifactissa, mutta se tarvitsee
   vielä tiheän real-combat- ja Android-katselmuksen.
2. Hyväksy tai hylkää uusi 10-pocket microprop-probe. Vain hyväksytty probe
   voi avata yhden uuden runtime decor family -slotin.
3. Tee valituille hero/boss body-bakeille erillinen source, licence, render,
   hash, alpha/pivot ja mobile-budget manifest; älä yhdistä niitä tämän
   dokumentin audit-lukuihin ennen todellista promoottia.
4. Vasta lopuksi kerää fyysiset Android-, kosketus-, audio-, lifecycle- ja
   kaksilaite-LAN-todisteet. Desktop-Mobil/Vulkan-kuva ei korvaa niitä.

## Evidence index

- `docs/ADDONS_DEEP_AUDIT.md`
- `artifacts/asset_audit/deep_asset_audit_summary.json`
- `docs/AAA_VISUAL_REDESIGN_AUDIT_2026-09-16.md`
- `artifacts/combat_composite_validation/`
- `artifacts/enemy_body_readability_validation/`
- `artifacts/vfx_gameplay_scale_validation/`
- `artifacts/existing_wild_atlas_context_validation/`
