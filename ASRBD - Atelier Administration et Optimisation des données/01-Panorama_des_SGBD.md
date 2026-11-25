# 01 - Panorama des principaux SGBD

---

## 1. Typologie des SGBD : Relationnels vs NoSQL

Un **SGBD** (Système de Gestion de Bases de Données) est le logiciel qui assure le stockage, la cohérence, la sécurité et l'accès concurrent aux données.

### SGBD Relationnels (SGBDR - Modèle ACID)
Les données sont structurées en **tables** (lignes et colonnes) reliées par des clés primaires/étrangères, interrogées en **SQL**. Ils garantissent les propriétés **ACID** :
- **A**tomicité : une transaction s'exécute entièrement ou pas du tout.
- **C**ohérence : les contraintes d'intégrité sont toujours respectées.
- **I**solation : les transactions concurrentes ne se corrompent pas mutuellement.
- **D**urabilité : une fois validée (`COMMIT`), la donnée survit aux pannes.

### SGBD NoSQL (Modèle BASE / Orienté documents, clé-valeur, colonnes, graphe)
Conçus pour la **scalabilité horizontale**, les schémas flexibles et les très forts volumes non structurés (ex. **MongoDB**). Ils privilégient souvent la disponibilité et la tolérance au partitionnement (théorème **CAP**) avec une cohérence éventuelle configurable.

---

## 2. Les 7 principaux SGBD du marché

| SGBD | Modèle | Licence / Modèle économique | OS principaux | Cas d'usage & points forts | Limites / Vigilance |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL** | Relationnel + objet (`JSONB`, `PostGIS`) | Open Source (licence PostgreSQL, gratuite) | Linux, Windows, macOS | Très complet (MVCC, extensions, conformité SQL), plébiscité en entreprise et cloud | Courbe d'apprentissage sur le tuning avancé (`VACUUM`, connexions) |
| **MySQL** | Relationnel | Open Source (GPL) / Commercial (Oracle) | Linux, Windows, macOS | Standard historique du web (LAMP), simple à déployer, réplication répandue | Gouvernance Oracle ; fonctionnalités avancées réservées à l'édition Enterprise |
| **MariaDB** | Relationnel | Open Source (GPL) | Linux, Windows | Fork communautaire de MySQL, compatible MySQL, moteurs de stockage variés | Légères divergences progressives avec MySQL 8+ |
| **SQL Server** | Relationnel | Propriétaire (Express/Dev gratuits ; Standard/Enterprise payants par cœur) | Windows, **Linux** | Écosystème intégré (T-SQL, SQL Agent, Query Store, SSIS/SSRS), performant | Coût des licences en production (Standard / Enterprise) |
| **Oracle Database** | Relationnel + multimodèle | Propriétaire (Free/XE limités ; SE2/EE très coûteux par cœur) | Linux, Unix, Windows | Référence grands comptes critiques (RAC, RMAN, ASM, PL/SQL) | Complexité et coût élevé des licences et options |
| **IBM Db2** | Relationnel | Propriétaire (Community gratuit limité ; Standard/Advanced payants) | Linux, Unix, Windows, z/OS | Systèmes bancaires, assurances, mainframes, haute fiabilité | Écosystème plus fermé, compétences DBA plus rares |
| **MongoDB** | NoSQL (Documents JSON/BSON) | Source-available (SSPL) / Cloud Atlas | Linux, Windows, macOS | Schéma flexible, prototypage rapide, sharding natif, catalogues / logs | Pas de jointures complexes natives performantes ; gestion mémoire (WiredTiger) |

---

## 3. Aperçu général de l'administration des 7 SGBD

> [!NOTE] Compétence transversale
> Quel que soit le SGBD utilisé, vous retrouvez toujours les mêmes briques : **client/configuration**, **stockage**, **journal de transactions**, **sauvegarde/reprise** et **supervision**.

| SGBD                | Client CLI & Config                                   | Stockage physique                             | Journal de transactions                      | Sauvegarde / Reprise                      | Supervision de base                          |
| :------------------ | :---------------------------------------------------- | :-------------------------------------------- | :------------------------------------------- | :---------------------------------------- | :------------------------------------------- |
| **PostgreSQL**      | `psql` · `postgresql.conf`, `pg_hba.conf`             | `PGDATA` + `TABLESPACE`                       | **WAL** (`pg_wal/`)                          | `pg_dump`, `pg_basebackup` / `pgBackRest` | `pg_stat_activity`, `pg_stat_statements`     |
| **MariaDB**         | `mariadb` · `/etc/mysql/mariadb.conf.d/*.cnf`         | `datadir` (InnoDB `.ibd`)                     | Redo logs + **Binary Log** (`binlog`)        | `mariadb-dump`, `mariabackup` (à chaud)   | `SHOW PROCESSLIST`, `performance_schema`     |
| **MySQL**           | `mysql` · `/etc/mysql/my.cnf`                         | `datadir` (InnoDB `.ibd`, `ibdata1`)          | Redo logs + **Binary Log** (`binlog`)        | `mysqldump`, `mysqlbackup` (Enterprise)   | `SHOW PROCESSLIST`, `performance_schema`     |
| **SQL Server**      | `sqlcmd` · `mssql-conf` (`/var/opt/mssql/mssql.conf`) | Fichiers `.mdf` / `.ndf` + Filegroups         | **Transaction Log** (`.ldf`)                 | `BACKUP` / `RESTORE DATABASE` natifs      | **DMVs** (`sys.dm_*`), **Query Store**       |
| **Oracle Database** | `sqlplus` · `spfile` / `init.ora`, `listener.ora`     | *Tablespaces* & Datafiles (`.dbf`, ASM)       | **Redo Logs** + Archived Redo Logs           | **RMAN** (*Recovery Manager*), Data Pump  | **V$ views** (`v$session`), **AWR / OEM**    |
| **IBM Db2**         | `db2` (CLP) · `DBM CFG` / `DB CFG`                    | *Tablespaces* (SMS / DMS / Automatic)         | Logs actifs / archivés (`LOGARCHMETH1`)      | `BACKUP` / `RESTORE DATABASE` natifs      | `MON_GET_*`, `db2pd`                         |
| **MongoDB**         | `mongosh` · `/etc/mongod.conf`                        | Collections & fichiers **WiredTiger** (`.wt`) | **Oplog** (replica set) + journal WiredTiger | `mongodump` / `mongorestore`, snapshots   | `db.serverStatus()`, `mongostat`, `mongotop` |

### 3.1 Définitions des termes techniques par SGBD

#### PostgreSQL
- **`PGDATA`** : répertoire racine d'un cluster PostgreSQL (ex. `/var/lib/postgresql/16/main`). Il contient les fichiers de configuration, les bases de données et les journaux.
- **`TABLESPACE`** : emplacement physique supplémentaire sur un autre disque ou point de montage, permettant de déplacer des tables ou index spécifiques hors de `PGDATA` (performance I/O ou capacité).
- **`WAL` (*Write-Ahead Logging*)** : journal de transactions situé dans `pg_wal/`. Toute modification est d'abord écrite dans le WAL avant d'être appliquée aux fichiers de données, garantissant la durabilité et la reprise après crash.
- **`pg_hba.conf`** : fichier contrôlant l'authentification des clients (qui peut se connecter, depuis quelle IP, à quelle base, et avec quelle méthode).
- **`pg_dump` / `pg_basebackup` / `pgBackRest`** : `pg_dump` réalise un export SQL logique d'une base ; `pg_basebackup` et `pgBackRest` réalisent des sauvegardes physiques à chaud avec archivage des WAL (restauration temporelle).
- **`pg_stat_activity` / `pg_stat_statements`** : vues système affichant respectivement les sessions/requêtes en cours et les statistiques cumulées des requêtes les plus coûteuses.

#### MariaDB & MySQL
- **`datadir`** : répertoire principal où sont stockées les bases et les tables (souvent `/var/lib/mysql`).
- **`InnoDB` (`.ibd`, `ibdata1`)** : moteur de stockage transactionnel par défaut. `ibdata1` est le tablespace système ; chaque table possède en plus son propre fichier `.ibd` (*file-per-table*).
- **`Binary Log` (`binlog`)** : journal enregistrant toutes les modifications de données (en SQL ou par lignes modifiées). Indispensable pour la **réplication** et la restauration à un instant T (*Point-in-Time Recovery*).
- **`mariadb-dump` / `mysqldump` vs `mariabackup`** : les outils `*-dump` produisent des exports logiques SQL (lents sur de très gros volumes) ; `mariabackup` copie les fichiers physiques à chaud sans bloquer les lectures/écritures.
- **`performance_schema`** : base interne collectant des métriques fines d'exécution (temps d'attente, verrous, requêtes lentes).

#### SQL Server
- **`mssql-conf`** : utilitaire CLI sous Linux modifiant `/var/opt/mssql/mssql.conf` (port TCP, activation de SQL Agent, chemins par défaut).
- **`.mdf` / `.ndf` / `.ldf`** : `.mdf` est le fichier de données principal ; `.ndf` sont des fichiers de données secondaires (répartis dans des **Filegroups** sur différents disques) ; `.ldf` est le **Transaction Log** (journal de transactions).
- **`DMVs` (*Dynamic Management Views*)** : vues système (`sys.dm_*`) exposant l'état interne en temps réel (mémoire, I/O, requêtes actives, blocages).
- **`Query Store`** : fonctionnalité intégrée qui conserve l'historique des plans d'exécution et des temps de réponse d'une base pour diagnostiquer les régressions de performance.

#### Oracle Database
- **`spfile` / `init.ora` / `listener.ora`** : `spfile` (binaire) et `init.ora` (texte) stockent les paramètres de l'instance ; `listener.ora` configure le service réseau (`TNS Listener`) qui reçoit les connexions clientes.
- **`Tablespaces` & `Datafiles` (`.dbf`) / `ASM`** : un *tablespace* est une unité logique de stockage composée d'un ou plusieurs fichiers physiques `.dbf`. **ASM** (*Automatic Storage Management*) est le gestionnaire de volumes/disques intégré d'Oracle.
- **`Redo Logs` & `Archived Redo Logs`** : journaux circulaires enregistrant chaque changement. Une fois pleins, ils sont copiés en *Archived Redo Logs* pour permettre la reprise complète.
- **`RMAN` (*Recovery Manager*) & `Data Pump`** : `RMAN` est l'outil de sauvegarde/restauration physique de référence ; `Data Pump` (`expdp`/`impdp`) gère l'export/import logique haute performance.
- **`V$ views` / `AWR` / `OEM`** : les vues `V$` donnent l'état temps réel ; **AWR** (*Automatic Workload Repository*) archive les performances ; **OEM** (*Oracle Enterprise Manager*) est l'interface web d'administration.

#### IBM Db2
- **`CLP` (*Command Line Processor*)** : interface `db2` en ligne de commande pour administrer l'instance et exécuter du SQL.
- **`DBM CFG` / `DB CFG`** : niveaux de configuration séparés entre le gestionnaire d'instance (*Database Manager*) et chaque base (*Database*).
- **`Tablespaces` (`SMS` / `DMS` / `Automatic`)** : conteneurs gérés par le système de fichiers (`SMS`), directement par Db2 (`DMS`), ou automatiquement (`Automatic Storage`).
- **`LOGARCHMETH1`** : paramètre définissant comment et où Db2 archive ses journaux de transactions actifs pour autoriser les sauvegardes à chaud.
- **`MON_GET_*` / `db2pd`** : fonctions SQL de monitoring et utilitaire d'inspection mémoire/verrous en temps réel.

#### MongoDB
- **`WiredTiger` (`.wt`)** : moteur de stockage par défaut de MongoDB (gestion des collections, index, compression et cache mémoire).
- **`Oplog` (*Operations Log*)** : collection plafonnée spéciale enregistrant toutes les opérations d'écriture ; elle permet la synchronisation des nœuds d'un **Replica Set** (haute disponibilité) et la reprise incrémentale.
- **`mongodump` / `mongorestore`** : utilitaires d'export/import binaire (`BSON`) des collections et bases.

