# 04 - TP1 : Prise en main et configuration de SQL Server 2025 sous Debian 13

> [!INFO] Prérequis & Organisation
> - **Modalité :** 1 VM Debian 13 par groupe (2 ou 3 élèves), droits `sudo` et `sa`.

## Etape 0 - Installation

**Installation de référence :** [[ANNEXE-Installation_SQLServer_Debian13]] (~2 Go RAM, port `1433`, `sqlcmd` via `mssql-tools18`).

---

## Étape 1 - Vérification de l'instance et activation de SQL Server Agent

1. Vérifiez l'état du service `mssql-server` et la configuration actuelle :
```bash
sudo systemctl status mssql-server
sudo cat /var/opt/mssql/mssql.conf
```

2. Activez **SQL Server Agent** (indispensable pour les prochaines séances sur les sauvegardes planifiées et les alertes), puis redémarrez le service :
```bash
sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
sudo systemctl restart mssql-server
```

3. Vérifiez la mémoire disponible sur la VM (`free -h`) : avec ~2 Go de RAM et sans swap par défaut, nous devrons borner la mémoire de SQL Server à l'étape 3 pour éviter qu'il ne sature le système.

---

## Étape 2 - Connexion et exploration des bases système

Connectez-vous en ligne de commande avec `sqlcmd` (adaptez le mot de passe `sa` défini lors de l'installation) :
```bash
sqlcmd -S localhost -U sa -P 'VotreMotDePasseSA' -C
```
*(L'option `-C` accepte le certificat TLS auto-signé de l'instance.)*

> [!TIP] Client graphique (optionnel)
> Vous pouvez aussi vous connecter depuis votre poste hôte avec **DataGrip**, **VS Code (extension MSSQL)**, **DBeaver** ou **SSMS** sur `<IP_DE_LA_VM>:1433` (dans DataGrip/JDBC et SSMS, activer `trustServerCertificate=true` si le certificat TLS auto-signé bloque).

Exécutez les requêtes suivantes pour inspecter l'instance :
```sql
-- 1. Version et édition de SQL Server 2025
SELECT @@VERSION;
GO

-- 2. Lister les bases système et leur modèle de récupération
SELECT name, database_id, state_desc, recovery_model_desc
FROM sys.databases;
GO

-- 3. Localiser tous les fichiers physiques (.mdf / .ldf)
SELECT DB_NAME(database_id) AS Base,
       name AS NomLogique,
       type_desc AS TypeFichier,
       physical_name AS Chemin,
       size * 8 / 1024 AS Taille_Mo
FROM sys.master_files
ORDER BY database_id;
GO
```

---

## Étape 3 - Création d'une base avec séparation stockage & sobriété (20 min)

### 3.1 Préparation des répertoires Linux
Simulez deux points de montage distincts pour séparer les fichiers de données (`.mdf`) et le journal de transactions (`.ldf`) :
```bash
sudo mkdir -p /var/opt/mssql/data_app /var/opt/mssql/log_app
sudo chown -R mssql:mssql /var/opt/mssql/data_app /var/opt/mssql/log_app
```

### 3.2 Création de la base `ERP_Epsi`
En `sqlcmd`, créez la base en spécifiant des tailles initiales maîtrisées et une croissance fixe en Mo (`FILEGROWTH` fixe plutôt qu'en pourcentage) :
```sql
CREATE DATABASE ERP_Epsi
ON PRIMARY (
    NAME = N'ERP_Epsi_Data',
    FILENAME = N'/var/opt/mssql/data_app/ERP_Epsi.mdf',
    SIZE = 64MB,
    MAXSIZE = 1024MB,
    FILEGROWTH = 64MB
)
LOG ON (
    NAME = N'ERP_Epsi_Log',
    FILENAME = N'/var/opt/mssql/log_app/ERP_Epsi_log.ldf',
    SIZE = 32MB,
    MAXSIZE = 512MB,
    FILEGROWTH = 32MB
);
GO
```

### 3.3 Plafonnement mémoire de l'instance

> [!NOTE] Rappel : Qu'est-ce que l'OOM Killer ?
> Sous Linux, lorsque la mémoire vive (RAM + swap) est totalement saturée et que le système risque de se figer, le noyau déclenche l'**OOM Killer** (*Out Of Memory Killer*) qui choisit et tue brutalement (`SIGKILL`) le processus qui consomme le plus de mémoire pour sauver le système. Comme SQL Server alloue beaucoup de RAM, il est la première cible : un arrêt brutal coupe toutes les connexions en cours et force une phase de récupération des journaux au redémarrage.

Sur une VM Debian 13 de ~2 Go de RAM, limitez SQL Server à **1280 Mo** pour préserver le noyau Linux et éviter l'OOM Killer :
```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory (MB)', 1280;
RECONFIGURE;
GO
```

---

## Points clés à retenir

> [!SUMMARY] Ce qu'il faut maîtriser à l'issue de ce TP

1. **Administration système sous Linux :**
   - Le moteur tourne via le service systemd `mssql-server` et sa configuration d'instance est centralisée dans `/var/opt/mssql/mssql.conf` (géré avec `mssql-conf`).
   - **SQL Server Agent** est désactivé par défaut sous Linux : il faut l'activer explicitement (`mssql-conf set sqlagent.enabled true` + redémarrage) pour pouvoir planifier des sauvegardes et des alertes.
   - Tout répertoire Linux utilisé par SQL Server (données, journaux, sauvegardes) doit appartenir à l'utilisateur système `mssql:mssql`.

2. **Connexion et diagnostic d'instance :**
   - `sqlcmd` (avec `-C` pour accepter le certificat TLS auto-signé) permet d'administrer l'instance en local ; les clients graphiques (**DataGrip**, **VS Code MSSQL**, **DBeaver**, **SSMS**) se connectent à distance sur le port TCP `1433`.
   - Les vues catalogue `sys.databases` et `sys.master_files` sont le point d'entrée pour auditer l'état des bases, leur modèle de récupération (`FULL` / `SIMPLE`) et l'emplacement réel de leurs fichiers.
   - Les 4 bases système ont chacune un rôle précis : `master` (configuration/logins), `model` (gabarit), `msdb` (Agent/historique backups) et `tempdb` (données temporaires recréées au démarrage).

1. **Optimisation du stockage physique :**
   - Toujours **séparer les fichiers de données** (`.mdf` / `.ndf`) **du journal de transactions** (`.ldf`) sur des volumes distincts : les écritures sur `.ldf` sont séquentielles alors que les accès aux données sont aléatoires.
   - Toujours définir une taille initiale (`SIZE`) réaliste, un plafond (`MAXSIZE`) et une croissance (`FILEGROWTH`) **fixe en Mo** plutôt qu'en pourcentage (pour éviter des extensions trop lentes et de la fragmentation).

1. **Gestion mémoire et sobriété :**
   - Par défaut, SQL Server peut consommer presque toute la RAM disponible.
   - Sur Linux (en particulier sur une VM de ~2 Go de RAM comme celle qu'on a faite), il est indispensable de borner `max server memory (MB)` via `sp_configure` + `RECONFIGURE` (ici `1280` Mo) afin de préserver le noyau Linux, le cache disque OS et éviter l'**OOM Killer**.


