# Kijiji — Instructions de compilation et exécution
# =====================================================

## Prérequis
- Java 17+ (JDK)
- JavaFX SDK 17+ : https://gluonhq.com/products/javafx/
- PostgreSQL JDBC driver (postgresql-42.x.x.jar)
- PostgreSQL installé et la base `kijiji_db` créée

## Structure du projet
```
kijiji/
├── src/main/java/kijiji/
│   ├── App.java
│   ├── db/
│   │   ├── Connexion.java
│   │   └── KijijiDAO.java
│   ├── model/
│   │   ├── Utilisateur.java
│   │   ├── Annonce.java
│   │   ├── Produit.java
│   │   ├── Proposition.java
│   │   └── Categorie.java
│   └── ui/
│       ├── LoginView.java
│       ├── AnnonceurView.java
│       ├── AcheteurView.java
│       └── dialogs/
│           ├── DialogSoumission.java
│           ├── DialogExpert.java
│           ├── DialogEstimation.java
│           └── DialogPropositions.java
├── lib/
│   ├── javafx-controls-17.jar    (et les autres jars JavaFX)
│   └── postgresql-42.x.x.jar
└── README.txt
```

## Étape 1 — Préparer la base de données
```bash
psql -U postgres
CREATE DATABASE kijiji_db;
\c kijiji_db
\i DDL.sql
\i LMD_data.sql
```

## Étape 2 — Placer les JARs dans lib/
- Télécharger JavaFX SDK et copier les fichiers .jar dans lib/
- Télécharger postgresql-42.x.x.jar et le copier dans lib/

## Étape 3 — Compiler
```bash
# Depuis le dossier kijiji/
javac --module-path lib \
      --add-modules javafx.controls,javafx.fxml \
      -cp "lib/*" \
      -d out \
      $(find src -name "*.java")
```

## Étape 4 — Exécuter
```bash
java --module-path lib \
     --add-modules javafx.controls,javafx.fxml \
     -cp "out:lib/*" \
     kijiji.App
```

## Étape 5 — Créer le JAR exécutable
```bash
# Créer le manifest
echo "Main-Class: kijiji.App" > manifest.txt

# Créer le JAR
jar cfm kijiji.jar manifest.txt -C out .

# Exécuter le JAR
java --module-path lib \
     --add-modules javafx.controls,javafx.fxml \
     -cp "kijiji.jar:lib/*" \
     kijiji.App
```

## Modifier les paramètres de connexion BD
Ouvrir src/main/java/kijiji/db/Connexion.java et modifier :
- URL      : jdbc:postgresql://localhost:5432/kijiji_db
- USER     : postgres
- PASSWORD : postgres

## Comptes de test (email / mot_de_passe)
Annonceur : lucas.tremblay@gmail.com   / hashed_pw_01
Acheteur  : raphael.charron@gmail.com  / hashed_pw_31
Expert    : edouard.lemay@gmail.com    / hashed_pw_41
