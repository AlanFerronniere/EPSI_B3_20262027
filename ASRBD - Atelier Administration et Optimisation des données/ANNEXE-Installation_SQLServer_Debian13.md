# Installation de SQL Server 2025 sous Debian 13 (Trixie)

---

## 0. Déploiement de la VM sur Proxmox

1. Connectez-vous à l'interface Proxmox : https://proxmox.labo.loc/
2. Clonez le template **`deb-trixie-cloud-b3`** en respectant les **règles de numérotation et d'adressage de Thierry** (VMID, nommage et IP `172.16.13X.XXX`).
3. Dans l'onglet **Cloud-Init** (ou dans `~/.ssh/authorized_keys` après démarrage), ajoutez **votre propre clé SSH publique** ainsi que **LA MIENNE** (pour que je puisse regarder ce que vous faites) :

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID9QsLHT+Nbad4VY1ElqIwEWp63ykDpQzHOIEDPV3NDR ferro@Marcus
```

---

## 1. Prérequis et contexte matériel

| Élément          | Valeur                                      | Remarque                                                                                                                                                          |
| ---------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **OS**           | Debian GNU/Linux 13 (`trixie`), `x86_64`    | Dépôt `mssql-server-2025` (Ubuntu 24.04 `noble`) compatible ABI (`libssl3t64`, `libldap2`)                                                                        |
| **RAM**          | ~1,9 GiB (`MemTotal: 2021548 kB`)           | Minimum requis par SQL Server (~2 Go). Envisager d'ajouter 2 Go de swap et de borner `max server memory (MB)` (ex. `1024`–`1536` Mo) si la VM reste à 2 Go de RAM |
| **Swap**         | `0B`                                        | Recommandé d'en ajouter en production / TP intensif pour éviter l'OOM killer                                                                                      |
| **Disque (`/`)** | `9,7G` total (`~8,3G` libres avant install) | L'installation consomme ~1,5 Go                                                                                                                                   |
| **Réseau**       | `172.16.13X.XXX`, port TCP `1433`           | Accessible depuis le réseau local                                                                                                                                 |

> [!NOTE] Choix des dépôts sur Debian 13
> Microsoft ne publie pas encore de dépôt dédié `debian/13` pour le moteur `mssql-server`, mais le dépôt **Ubuntu 24.04 (`mssql-server-2025`)** s'installe sans conflit de dépendances sur Debian 13. Les outils clients (`mssql-tools18`, `msodbcsql18`) disposent quant à eux d'un dépôt officiel `debian/13`.

---

## 2. Installation des prérequis et ajout des dépôts Microsoft

1. Installer `gnupg` et `curl` :
```bash
sudo apt-get update
sudo apt-get install -y gnupg curl
```

2. Importer les clés GPG Microsoft (la clé historique `microsoft.asc` pour `mssql-server-2025` et la clé `microsoft-2025.asc` utilisée par le dépôt `debian/13/prod`) dans `/usr/share/keyrings/microsoft-prod.gpg` :
```bash
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg

curl -fsSL https://packages.microsoft.com/keys/microsoft-2025.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod-2025.gpg

sudo sh -c 'cat /usr/share/keyrings/microsoft-prod-2025.gpg >> /usr/share/keyrings/microsoft-prod.gpg'
sudo rm -f /usr/share/keyrings/microsoft-prod-2025.gpg
```

3. Ajouter les deux dépôts (`mssql-server-2025` et `msprod` pour `sqlcmd`) puis mettre à jour l'index `apt` :
```bash
curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/mssql-server-2025.list \
  | sudo tee /etc/apt/sources.list.d/mssql-server-2025.list

curl -fsSL https://packages.microsoft.com/config/debian/13/prod.list \
  | sudo tee /etc/apt/sources.list.d/msprod.list

sudo apt-get update
```

---

## 3. Installation de SQL Server et des outils CLI (`sqlcmd`)

```bash
sudo DEBIAN_FRONTEND=noninteractive ACCEPT_EULA=Y \
  apt-get install -y mssql-server mssql-tools18 unixodbc-dev
```

*(Versions installées lors de la mise en place : `mssql-server 17.0.5065.9-3`, `mssql-tools18 18.7.1.1-1`, `msodbcsql18 18.7.1.1-1`.)*

---

## 4. Configuration initiale de l'instance

Exécuter l'assistant `mssql-conf setup` (en mode non-interactif avec l'édition **Developer** et le mot de passe `sa` du TP) :

```bash
sudo MSSQL_PID=Developer ACCEPT_EULA=Y MSSQL_SA_PASSWORD='EpsiB3!2026Password' \
  /opt/mssql/bin/mssql-conf -n setup
```

Ajouter `/opt/mssql-tools18/bin` au `PATH` système et utilisateur pour disposer de `sqlcmd` directement :

```bash
printf 'export PATH="$PATH:/opt/mssql-tools18/bin"\n' | sudo tee /etc/profile.d/mssql-tools.sh
printf 'export PATH="$PATH:/opt/mssql-tools18/bin"\n' >> ~/.bashrc
source ~/.bashrc
```

---

## 5. Vérifications post-installation

### Service systemd et écoute réseau
```bash
sudo systemctl status mssql-server --no-pager
ss -tlnp | grep 1433
```
Attendu : service `active (running)` et socket en écoute sur `0.0.0.0:1433` / `*:1433`.

### Test de connexion locale (`sqlcmd`)
```bash
sqlcmd -S localhost -U sa -P 'EpsiB3!2026Password' -C -Q "SELECT @@VERSION"
```
Résultat obtenu :
> `Microsoft SQL Server 2025 (RTM-CU11) (KB5129223) - 17.0.5065.9 (X64)`
> `Enterprise Developer Edition (64-bit) on Linux (Debian GNU/Linux 13 (trixie)) <X64>`

### Test de connectivité distante depuis Windows (PowerShell)
```powershell
Test-NetConnection -ComputerName 172.16.130.77 -Port 1433
```
Attendu : `TcpTestSucceeded : True`.

---

## 6. Pour les séances de TP qui vont suivre

- **Activer SQL Server Agent**
  ```bash
  sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true
  sudo systemctl restart mssql-server
  ```