# TP — Créer des fichiers Bicep avec Visual Studio Code

**Durée estimée :** 30–45 min  
**Niveau :** Débutant  
**Objectif :** Déployer un compte de stockage et un réseau virtuel sur Azure en utilisant Bicep et VS Code.

---

## Prérequis

Avant de commencer, vérifier que vous avez :

- [ ] Un compte Azure actif (ou [créer un compte gratuit](https://azure.microsoft.com/free/))
- [ ] Visual Studio Code installé
- [ ] Extension **Bicep** installée dans VS Code
- [ ] Azure CLI installé et connecté (`az login`)

Vérifier l'installation :
```powershell
az --version
bicep --version
```

---

## Partie 1 — Créer le fichier Bicep

### Étape 1.1 — Nouveau fichier

1. Ouvrir VS Code
2. Créer un nouveau fichier nommé **`main.bicep`**

---

### Étape 1.2 — Ajouter un réseau virtuel via snippet

Dans `main.bicep`, taper `vnet`, sélectionner **`res-vnet`** dans la liste, puis appuyer sur **TAB** ou **ENTRÉE**.

Le code suivant est inséré automatiquement :

```bicep
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: 'name'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'Subnet-2'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}
```

> **Observation :** Vous voyez deux soulignements ?
> - 🟡 Jaune = avertissement (version API obsolète)
> - 🔴 Rouge = erreur (paramètre manquant)

**Corriger la version API :**  
Survoler la version API (`@2019-11-01`) → cliquer **Quick fix** → **Replace with latest**.

**Renommer la ressource :**  
Changer `name: 'name'` → `name: 'exampleVNet'`

---

## Partie 2 — Ajouter des paramètres

### Étape 2.1 — Paramètre `location`

En haut du fichier, ajouter :

```bicep
param location string = resourceGroup().location
```

Cela assigne automatiquement la région du groupe de ressources à la ressource.

---

### Étape 2.2 — Paramètre `storageAccountName`

Ajouter sous `location` :

```bicep
@minLength(3)
@maxLength(24)
@description('Provide a name for the storage account. Use only lowercase letters and numbers. The name must be unique across Azure.')
param storageAccountName string = 'store${uniqueString(resourceGroup().id)}'
```

> **Note :** Les décorateurs `@minLength` et `@maxLength` imposent les contraintes de nommage Azure.  
> `uniqueString()` génère un suffixe unique basé sur l'ID du groupe de ressources.

---

## Partie 3 — Ajouter le compte de stockage

### Étape 3.1 — Définir la ressource

Sous le réseau virtuel, ajouter :

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
```

> **Astuce IntelliSense :** Après `resource storageAccount`, taper un espace et laisser IntelliSense proposer les types. Taper `storageacc` pour filtrer. Après avoir choisi le type, taper `= ` puis choisir **required-properties**.

---

## Partie 4 — Fichier final complet

Votre `main.bicep` doit ressembler à ceci :

```bicep
@minLength(3)
@maxLength(24)
@description('Provide a name for the storage account. Use only lowercase letters and numbers. The name must be unique across Azure.')
param storageAccountName string = 'store${uniqueString(resourceGroup().id)}'

param location string = resourceGroup().location

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: 'exampleVNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'Subnet-2'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
```

---

## Partie 5 — Visualiser les ressources

1. Ouvrir `main.bicep` dans VS Code
2. Cliquer le bouton **Bicep Visualizer** en haut à droite
3. Observer le graphe — les deux ressources n'ont pas de dépendance entre elles (pas de connecteur)

---

## Partie 6 — Déployer le fichier Bicep

### Option A — Via VS Code

1. Clic droit sur `main.bicep` → **Deploy Bicep file**
2. Nom du déploiement : `deployStorageAndVNet`
3. Groupe de ressources : créer **`exampleRG`**
4. Région : **East US** (ou votre choix)
5. Fichier de paramètres : **None**

### Option B — Via Azure CLI (PowerShell)

```powershell
az group create --name exampleRG --location eastus

az deployment group create `
  --resource-group exampleRG `
  --template-file ./main.bicep `
  --parameters storageAccountName="uniquename123"
```

Vérifier le déploiement :
```powershell
az resource list --resource-group exampleRG --output table
```

---

## Partie 7 — Nettoyer les ressources

Une fois le TP terminé, supprimer le groupe de ressources pour éviter des frais :

```powershell
az group delete --name exampleRG --yes --no-wait
```

---

## Questions de révision

1. À quoi sert la fonction `uniqueString()` dans Bicep ?
2. Quelle est la différence entre un **snippet** et l'IntelliSense dans VS Code ?
3. Pourquoi utilise-t-on `resourceGroup().location` comme valeur par défaut ?
4. Que signifie le décorateur `@minLength(3)` sur un paramètre ?
5. Les deux ressources déployées ont-elles une dépendance ? Comment le vérifier ?

---

## Résumé des concepts clés

| Concept | Description |
|---|---|
| `param` | Déclare un paramètre réutilisable |
| `resource` | Déclare une ressource Azure à déployer |
| `@decorator` | Ajoute des contraintes ou métadonnées à un paramètre |
| `uniqueString()` | Génère un hash unique basé sur un ID |
| `resourceGroup()` | Référence le groupe de ressources cible |
| Snippet | Modèle de code prédéfini dans l'extension Bicep |
