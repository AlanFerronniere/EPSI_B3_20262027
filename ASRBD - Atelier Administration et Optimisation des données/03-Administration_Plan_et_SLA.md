# 03 - Plan d'administration, SLA et outils SQL Server sous Linux

---

## 1. Les 5 piliers de l'administration d'une base de données

Administrer une base de données ne consiste pas uniquement à créer des tables : le DBA garantit la **disponibilité**, l'**intégrité**, la **sécurité** et la **performance** des données sur la durée.

1. **Instance & Configuration** : dimensionnement mémoire/CPU, paramètres moteur, gestion des connexions.
2. **Stockage physique** : séparation des fichiers de données, journaux de transactions et fichiers temporaires sur des supports adaptés.
3. **Sécurité & Accès** : authentification, logins/rôles, principe du moindre privilège, chiffrement.
4. **Sauvegarde & Reprise** : stratégie de backup alignée sur le PRA, tests de restauration réguliers.
5. **Supervision & Optimisation** : suivi des indicateurs (CPU, I/O, verrous, espace disque), analyse des requêtes lentes.

---

## 2. Le Plan d'administration et le Contrat de Services (SLA)

### 2.1 Qu'est-ce qu'un Plan d'administration ?
C'est le document de référence qui formalise **les opérations récurrentes** (sauvegardes, contrôles d'intégrité, purges, réindexation, revue des alertes), leur **fréquence**, leurs **responsables** et les **indicateurs techniques** associés.

### 2.2 Indicateurs techniques à prendre en compte
- **Volumétrie actuelle et croissance estimée** (ex. +5 Go/mois → anticiper l'espace disque et la durée des sauvegardes).
- **Fenêtres de maintenance** : plages horaires de faible activité pour exécuter les opérations lourdes (`DBCC CHECKDB`, maintenance d'index).
- **Ressources matérielles & sobriété (`ASRBD1.7`)** : éviter le sur-dimensionnement, borner la mémoire du SGBD pour préserver l'OS, purger les données obsolètes et supprimer les index inutilisés.
- **Objectifs de reprise :**
  - **RPO (*Recovery Point Objective*)** : perte maximale de données tolérée (ex. 15 minutes).
  - **RTO (*Recovery Time Objective*)** : durée maximale d'indisponibilité tolérée (ex. 1 heure).

### 2.3 Importance du contrat de services (SLA)
> [!IMPORTANT] Le SLA dicte l'architecture et les procédures
> Ce n'est pas l'outil technique qui décide du niveau de service, mais le **SLA (Service Level Agreement)** signé avec le métier.

Un SLA de **99,9 %** de disponibilité implique au maximum ~8 h 45 d'indisponibilité cumulée par an : cela impose directement la fréquence des sauvegardes, le niveau de supervision (alertes proactives) et éventuellement une architecture haute disponibilité.

---

## 3. Outils d'administration : du monde Oracle à SQL Server sous Linux

Dans un environnement **Oracle**, l'administration s'appuie classiquement sur :
- *SQL\*Plus / SQL\*DBA* (ligne de commande)
- *Oracle Network Manager* (configuration réseau / listener)
- *Oracle Enterprise Manager (OEM)* (supervision web et alertes)
- *SQL Developer / SQL Studio* (requêtage et gestion graphique)

Dans notre environnement **SQL Server 2025 sous Debian 13**, on retrouve exactement les mêmes fonctions :

| Rôle | Outil SQL Server sous Linux | Description |
| :--- | :--- | :--- |
| **Service moteur** | `systemctl` (`mssql-server`) | Démarrer, arrêter, vérifier l'état du moteur SQL Server |
| **Configuration instance** | `mssql-conf` (`/var/opt/mssql/mssql.conf`) | Port TCP (1433), activation de SQL Agent, chemins par défaut, mémoire |
| **Client CLI** | `sqlcmd` (`mssql-tools18`) | Exécution de requêtes T-SQL et scripts d'administration en terminal |
| **Client graphique** | **DataGrip** / **VS Code (extension MSSQL)** / **DBeaver** / **SSMS** | Connexion distante sur le port `1433`, exploration des objets, plans d'exécution |
| **Automatisation & Alertes** | **SQL Server Agent** | Planification de jobs (sauvegardes, `CHECKDB`), alertes et notifications |
| **Supervision interne** | **DMVs** (`sys.dm_*`) & **Query Store** | Vues système temps réel et historique des performances de requêtes |

### Les 4 bases système indispensables de SQL Server
- **`master`** : cœur de l'instance (logins, configuration serveur, liste et emplacement des bases).
- **`model`** : gabarit copié à chaque nouveau `CREATE DATABASE`.
- **`msdb`** : planification SQL Server Agent (jobs, alertes, opérateurs) et historique des sauvegardes.
- **`tempdb`** : espace de travail temporaire (tris, jointures, tables `#temp`), recréé à chaque démarrage de l'instance.
