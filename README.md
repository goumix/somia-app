# Somia

**Comprendre son corps sur le long terme.**

App iOS / Apple Watch qui détecte le *physiological drift* : la dégradation lente et silencieuse des signaux physiologiques sur 14 à 30 jours, à partir des données HealthKit.

> **Statut : projet terminé (octobre 2026).**
> Somia a été publiée sur l'App Store en achat unique et a dépassé les 10 ventes. Le projet est arrêté depuis l'annonce de la refonte de l'app Santé d'Apple, qui intègre nativement l'analyse de tendances long terme. Ce repo est conservé à titre de portfolio.

<img width="1242" height="2688" alt="3" src="https://github.com/user-attachments/assets/86f30b12-3ca2-46b8-9711-e36f66a1605a" />
<img width="1242" height="2688" alt="2" src="https://github.com/user-attachments/assets/1b77cdd9-b4f6-4917-af77-f60acead6605" />
<img width="1050" height="600" alt="1" src="https://github.com/user-attachments/assets/b6a4c608-e0ed-4e93-aad6-3008d5227a04" />
<img width="1242" height="2688" alt="1" src="https://github.com/user-attachments/assets/7b791eca-f281-420c-ab27-a111bcc6d63d" />


---

## Le problème

L'Apple Watch collecte des centaines de signaux chaque nuit. Apple Santé les stocke sous forme de graphiques, mais ne les interprète pas sur la durée. Les apps existantes (Whoop, Oura, Bevel) optimisent la performance **du jour**.

Somia répond à une autre question : *est-ce que mon corps dérive depuis plusieurs semaines sans que je m'en rende compte ?*

## Fonctionnement

- **Baseline personnelle** : chaque utilisateur est comparé à lui-même (médiane glissante sur 60 jours), jamais à une moyenne de population. Les 7 premiers jours servent d'observation silencieuse.
- **Score de dérive** de −100 à +100, calculé sur les tendances des 30 derniers jours, toujours affiché avec un label (*Stable*, *En dérive légère*, *En progression*…).
- **Un insight par jour** en langage naturel, généré à partir de templates paramétrés.
- **Architecture en 3 couches** : score + insight → métriques du matin → tendances et corrélations sur 30 jours.

### Signaux utilisés

| Signal | Identifiant HealthKit | Poids dans le score |
|---|---|---|
| HRV nocturne | `heartRateVariabilitySDNN` | 35 % |
| FC au repos | `restingHeartRate` | 25 % |
| Sommeil | `sleepAnalysis` | 25 % |
| SpO2 | `oxygenSaturation` | 10 % |
| Fréquence respiratoire, pas, VO2max | `respiratoryRate`, `stepCount`, `vo2Max` | 5 % |

## Choix techniques

- **100 % on-device** : aucun backend, aucun appel réseau, aucun LLM externe. Les données de santé ne quittent jamais l'iPhone.
- **Achat unique, sans abonnement** : sans serveur, il n'y a aucun coût récurrent à répercuter sur l'utilisateur.
- **Cadre non médical strict** : l'app parle de « signal à surveiller », jamais de diagnostic.
- **Pas de gamification** : ni streaks, ni badges, ni comparaison entre utilisateurs.

## Stack

- Swift, SwiftUI, `@Observable`, async/await
- HealthKit (lecture seule)
- Swift Charts
- Accelerate.framework pour les statistiques on-device
- Architecture MVVM

### Architecture

- `HealthKitManager` : singleton conforme au protocole `HealthKitManaging`, seul point d'accès à HealthKit.
- `HealthKitManagerMock` : implémentation factice injectée sur le simulateur, qui n'a pas accès aux données HealthKit réelles.
- ViewModels `@Observable` par écran, vues SwiftUI sans logique métier.

## Lancer le projet

Prérequis : un Mac avec Xcode et, pour des données réelles, un iPhone appairé à une Apple Watch Series 6 ou plus récente.

```bash
git clone https://github.com/<user>/somia-app.git
cd somia-app
open Somia.xcodeproj
```

- **Simulateur** : l'app utilise automatiquement `HealthKitManagerMock`, avec des données de démonstration.
- **Appareil réel** : choisir votre équipe de signature dans *Signing & Capabilities*, puis autoriser l'accès HealthKit au premier lancement.

## Liens

- Site : [getsomia.com](https://www.getsomia.com)
- App Store : [Somia](https://apps.apple.com/fr/app/somia/id6762608804)

## Licence

Code partagé à titre de portfolio. Tous droits réservés.
