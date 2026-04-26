## Codemagic build

Projekt je teraz pripraveny tak, aby Codemagic vedel vygenerovat chybajucu Android strukturu sam a potom postavit release APK.

### Co som pripravil

- upravil som `codemagic.yaml`, aby:
  - overil pritomnost `pubspec.yaml` a `lib/main.dart`
  - vygeneroval cisty Android projekt cez `flutter create`
  - obnovil tvoje zdrojove subory po vygenerovani
  - doplnil `INTERNET` a `POST_NOTIFICATIONS` permission iba ak chybaju
  - postavil `app-release.apk`
- odstranil som nekompletny `financne_indexy/android/build.gradle`, ktory mohol sposobovat konflikty
- lokalne BUY / BUY++ notifikacie su pripravene aj pre Codemagic build

### Co este chyba mimo repozitara

- nahrat tento repozitar do GitHub, GitLab alebo Bitbucket
- v Codemagicu pridat aplikaciu z repozitara
- pri prvom builde vybrat workflow `android-build`

### Co uz nepotrebujes robit rucne

- vytvarat cely Android projekt lokalne
- upravovat `AndroidManifest.xml`
- spustat `flutter pub get` pred Codemagic buildom

### Co ostava ako mozne neskorsie vylepsenie

- doplnit podpisovanie release buildu, ak budes chciet APK distribuovat ako oficialnu release verziu
- commitnut `pubspec.lock`, ked budes mat lokalne nainstalovany Flutter a spravis prvy `flutter pub get`
- neskor zmenit Android package name z predvoleneho `com.example`, ak budes chciet produkcnu identitu aplikacie
