# Mock AI Test Cases

Ce document regroupe plusieurs jeux de mock data pour tester le comportement de l'application et de l'IA.

Le format de sortie attendu par l'IA pour un diagnostic complet est le suivant:

```json
{
  "safety": "safe | caution | do_not_drive",
  "issue": "resume court du probleme",
  "dtcs": [
    {
      "code": "P0171",
      "meaning": "System Too Lean",
      "status": "stored | pending",
      "severity": "low | medium | high | critical"
    }
  ],
  "evidence": ["indices utilises pour conclure"],
  "causes": [
    {
      "cause": "cause probable",
      "confidence": "low | medium | high",
      "why": "raison courte"
    }
  ],
  "uncertain": ["donnees manquantes ou a verifier"],
  "actions": [
    {
      "priority": "now | this_week | next_service",
      "action": "action conseillee"
    }
  ],
  "urgency": "now | this_week | next_service",
  "message": "message court en langage utilisateur"
}
```

## Cas 1 - Mock actuel de l'application

### Mock data

```json
{
  "vin": "1NXBR32E14Z123456",
  "supported_pids": ["01", "04", "05", "0C", "0D", "10", "11"],
  "stored_dtcs": ["P0171", "P0300"],
  "pending_dtcs": ["P0171"],
  "freeze_frames": [
    {
      "DTC": "P0171",
      "Engine RPM": "750 RPM",
      "Coolant Temp": "92C",
      "Short Term Fuel Trim": "+15.6%"
    }
  ],
  "pid_values_raw": {
    "05": "94",
    "0C": "750",
    "10": "1.8",
    "06": "14.8"
  }
}
```

### Reponse attendue de l'IA

```json
{
  "safety": "caution",
  "issue": "Melange pauvre avec ratés d'allumage detectes.",
  "dtcs": [
    {
      "code": "P0171",
      "meaning": "System Too Lean (Bank 1)",
      "status": "stored",
      "severity": "high"
    },
    {
      "code": "P0300",
      "meaning": "Random/Multiple Cylinder Misfire Detected",
      "status": "stored",
      "severity": "critical"
    }
  ],
  "evidence": [
    "P0171 present in stored and pending memory",
    "P0300 present in stored memory",
    "Freeze frame shows 750 RPM and 92C coolant",
    "Short term fuel trim at +15.6% suggests the ECU is adding fuel"
  ],
  "causes": [
    {
      "cause": "Fuite d'air ou fuite de vide",
      "confidence": "high",
      "why": "Peut creer un melange pauvre et faire monter le fuel trim."
    },
    {
      "cause": "Debitmetre d'air (MAF) sale ou incoherent",
      "confidence": "medium",
      "why": "La mesure d'air incorrecte perturbe le calcul du carburant."
    },
    {
      "cause": "Pression carburant insuffisante ou injecteur faible",
      "confidence": "medium",
      "why": "Un manque de carburant peut provoquer melange pauvre et misfire."
    }
  ],
  "uncertain": [
    "Etat des bougies et bobines non connu",
    "Test de pression carburant non disponible",
    "Aucune mesure d'air d'admission detaillee"
  ],
  "actions": [
    {
      "priority": "now",
      "action": "Verifier les ratés d'allumage, les prises d'air et les durites de vide."
    },
    {
      "priority": "this_week",
      "action": "Controler MAF, bougies, bobines et pression carburant."
    },
    {
      "priority": "next_service",
      "action": "Effacer les codes apres reparation et refaire un scan routier."
    }
  ],
  "urgency": "now",
  "message": "Le moteur presente un melange pauvre avec des ratés. Il faut verifier rapidement l'admission, l'allumage et l'alimentation carburant."
}
```

## Cas 2 - Vehicule sain, aucune anomalie

### Mock data

```json
{
  "vin": "2T1BURHE5JC123456",
  "supported_pids": ["01", "04", "05", "0C", "0D", "10", "11"],
  "stored_dtcs": [],
  "pending_dtcs": [],
  "freeze_frames": [],
  "pid_values_raw": {
    "05": "88",
    "0C": "760",
    "10": "2.2",
    "04": "18",
    "0D": "0",
    "ATRV": "13.8V"
  }
}
```

### Reponse attendue de l'IA

```json
{
  "safety": "safe",
  "issue": "Aucun defaut actif detecte.",
  "dtcs": [],
  "evidence": [
    "Aucun DTC stocke ni en attente",
    "Regime moteur stable au ralenti",
    "Voltage batterie/alternateur correct"
  ],
  "causes": [],
  "uncertain": [
    "Certains capteurs non lus ne peuvent pas etre verifies",
    "Le vehicule peut avoir des defauts intermittents non presents au moment du scan"
  ],
  "actions": [
    {
      "priority": "next_service",
      "action": "Conserver le suivi et refaire un scan si un voyant apparait."
    }
  ],
  "urgency": "next_service",
  "message": "Aucun defaut actif n'a ete detecte. Le vehicule semble sain au moment du scan."
}
```

## Cas 3 - Surchauffe moteur

### Mock data

```json
{
  "vin": "JHMCM56557C123456",
  "supported_pids": ["01", "04", "05", "0C", "0D", "10", "11"],
  "stored_dtcs": ["P0217"],
  "pending_dtcs": ["P0217"],
  "freeze_frames": [
    {
      "DTC": "P0217",
      "Engine RPM": "2100 RPM",
      "Coolant Temp": "114C",
      "Speed": "82 km/h"
    }
  ],
  "pid_values_raw": {
    "05": "114",
    "0C": "2100",
    "0D": "82",
    "10": "3.8",
    "ATRV": "13.9V"
  }
}
```

### Reponse attendue de l'IA

```json
{
  "safety": "do_not_drive",
  "issue": "Surchauffe moteur detectee.",
  "dtcs": [
    {
      "code": "P0217",
      "meaning": "Engine Overtemperature Condition",
      "status": "stored",
      "severity": "critical"
    }
  ],
  "evidence": [
    "Coolant temperature at 114C",
    "P0217 present in stored and pending memory",
    "Vehicle was running at speed when the fault appeared"
  ],
  "causes": [
    {
      "cause": "Niveau de liquide de refroidissement trop bas",
      "confidence": "high",
      "why": "Une perte de liquide ou une fuite empeche le refroidissement."
    },
    {
      "cause": "Thermostat bloque ou pompe a eau defaillante",
      "confidence": "high",
      "why": "Le circuit ne peut plus evacuer correctement la chaleur."
    },
    {
      "cause": "Ventilateur ou relais de refroidissement defectueux",
      "confidence": "medium",
      "why": "La temperature monte surtout en charge ou en circulation lente."
    }
  ],
  "uncertain": [
    "Niveau liquide de refroidissement non mesure",
    "Etat du ventilateur non confirme",
    "Aucune lecture de pression circuit"
  ],
  "actions": [
    {
      "priority": "now",
      "action": "Arreter le vehicule et laisser refroidir le moteur."
    },
    {
      "priority": "now",
      "action": "Verifier le niveau de liquide de refroidissement et les fuites visibles."
    },
    {
      "priority": "this_week",
      "action": "Contrôler thermostat, pompe a eau, ventilateur et circuit de refroidissement."
    }
  ],
  "urgency": "now",
  "message": "La temperature moteur est trop elevee. Il faut arreter la conduite et verifier le circuit de refroidissement avant de reprendre la route."
}
```

## Cas 4 - Batterie faible / tension de charge basse

### Mock data

```json
{
  "vin": "3FA6P0H74HR123456",
  "supported_pids": ["01", "04", "05", "0C", "0D", "10", "11"],
  "stored_dtcs": ["P0562"],
  "pending_dtcs": [],
  "freeze_frames": [
    {
      "DTC": "P0562",
      "Engine RPM": "850 RPM",
      "Battery Voltage": "11.4V"
    }
  ],
  "pid_values_raw": {
    "05": "90",
    "0C": "850",
    "0D": "0",
    "10": "2.0",
    "ATRV": "11.4V"
  }
}
```

### Reponse attendue de l'IA

```json
{
  "safety": "caution",
  "issue": "Tension batterie/charge trop basse.",
  "dtcs": [
    {
      "code": "P0562",
      "meaning": "System Voltage Low",
      "status": "stored",
      "severity": "high"
    }
  ],
  "evidence": [
    "Battery voltage at 11.4V",
    "P0562 stored",
    "Engine idling at low rpm with low electrical margin"
  ],
  "causes": [
    {
      "cause": "Batterie fatiguee ou dechargee",
      "confidence": "high",
      "why": "La tension est deja sous le niveau normal attendu."
    },
    {
      "cause": "Alternateur ou regulateur de charge defectueux",
      "confidence": "high",
      "why": "Le systeme de charge ne maintient pas la tension."
    },
    {
      "cause": "Cosses ou masse mal serrees",
      "confidence": "medium",
      "why": "Une mauvaise connexion peut faire chuter la tension lue."
    }
  ],
  "uncertain": [
    "Test de charge batterie non fait",
    "Tension moteur accelere non disponible"
  ],
  "actions": [
    {
      "priority": "now",
      "action": "Verifier l'etat de la batterie et les cosses."
    },
    {
      "priority": "this_week",
      "action": "Tester l'alternateur et le regulateur de charge."
    },
    {
      "priority": "next_service",
      "action": "Remplacer la batterie si elle ne tient plus la charge."
    }
  ],
  "urgency": "this_week",
  "message": "La tension est trop basse pour etre rassurante. Il faut controler la batterie et le circuit de charge rapidement."
}
```

## Cas 5 - Defaut capteur vitesse vehicule

### Mock data

```json
{
  "vin": "WVWZZZ1JZXW123456",
  "supported_pids": ["01", "04", "05", "0C", "0D", "10", "11"],
  "stored_dtcs": ["P0500"],
  "pending_dtcs": ["P0500"],
  "freeze_frames": [
    {
      "DTC": "P0500",
      "Engine RPM": "2200 RPM",
      "Speed": "0 km/h",
      "Throttle Position": "28%"
    }
  ],
  "pid_values_raw": {
    "05": "87",
    "0C": "2200",
    "0D": "0",
    "10": "2.4",
    "ATRV": "13.7V"
  }
}
```

### Reponse attendue de l'IA

```json
{
  "safety": "caution",
  "issue": "Signal de vitesse vehicule incoherent ou absent.",
  "dtcs": [
    {
      "code": "P0500",
      "meaning": "Vehicle Speed Sensor Malfunction",
      "status": "stored",
      "severity": "medium"
    }
  ],
  "evidence": [
    "P0500 stored and pending",
    "Freeze frame shows engine rpm at 2200 while speed stays at 0",
    "Vehicle speed signal appears missing"
  ],
  "causes": [
    {
      "cause": "Capteur de vitesse defectueux",
      "confidence": "high",
      "why": "C'est la cause la plus directe du code P0500."
    },
    {
      "cause": "Cablage ou connecteur endommage",
      "confidence": "medium",
      "why": "Une liaison intermittente peut couper le signal."
    },
    {
      "cause": "Probleme ABS/ECU selon l'architecture du vehicule",
      "confidence": "low",
      "why": "Le signal vitesse peut transiter par un autre module."
    }
  ],
  "uncertain": [
    "Lecture du capteur vitesse brut non disponible",
    "Etat des connecteurs non confirme"
  ],
  "actions": [
    {
      "priority": "this_week",
      "action": "Verifier le capteur de vitesse et son faisceau."
    },
    {
      "priority": "this_week",
      "action": "Contrôler les donnees ABS et le signal vitesse au diagnostic."
    }
  ],
  "urgency": "this_week",
  "message": "Le signal de vitesse semble incoherent. Le vehicule peut encore rouler, mais le systeme doit etre controle rapidement."
}
```

