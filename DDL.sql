-- ============================================================
--  DDL.sql  —  Système de vente type Kijiji
--  IFT    |  Base de données PostgreSQL
-- ============================================================

-- Suppression des tables dans l'ordre inverse des dépendances
DROP TABLE IF EXISTS proposition   CASCADE;
DROP TABLE IF EXISTS estimation    CASCADE;
DROP TABLE IF EXISTS annonce       CASCADE;
DROP TABLE IF EXISTS produit       CASCADE;
DROP TABLE IF EXISTS categorie     CASCADE;
DROP TABLE IF EXISTS utilisateur   CASCADE;

-- ============================================================
--  1. UTILISATEUR
--     Entité centrale. Le rôle (annonceur / acheteur / expert)
--     est implicite selon les FK dans les autres tables.
-- ============================================================
CREATE TABLE utilisateur (
    id_utilisateur  SERIAL          PRIMARY KEY,
    nom             VARCHAR(100)    NOT NULL,
    prenom          VARCHAR(100)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    mot_de_passe    VARCHAR(255)    NOT NULL,
    telephone       CHAR(12),                        -- format : 514-123-4567
    adresse         VARCHAR(255),
    date_inscription DATE           NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT chk_telephone CHECK (
        telephone IS NULL OR telephone ~ '^\d{3}-\d{3}-\d{4}$'
    ),
    CONSTRAINT chk_email CHECK (
        email ~ '^[^@]+@[^@]+\.[^@]+$'
    )
);

-- ============================================================
--  2. CATEGORIE
--     Permet de classer les produits (électronique, meubles…)
-- ============================================================
CREATE TABLE categorie (
    id_categorie    SERIAL          PRIMARY KEY,
    nom             VARCHAR(100)    NOT NULL UNIQUE,
    description     TEXT
);

-- ============================================================
--  3. PRODUIT
--     Soumis par un annonceur (utilisateur).
--     Lié à une catégorie.
--     Le statut évolue via la table ANNONCE.
-- ============================================================
CREATE TABLE produit (
    id_produit      SERIAL          PRIMARY KEY,
    id_utilisateur  INT             NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    id_categorie    INT             NOT NULL REFERENCES categorie(id_categorie)    ON DELETE RESTRICT,
    titre           VARCHAR(200)    NOT NULL,
    description     TEXT,
    etat            VARCHAR(20)     NOT NULL DEFAULT 'usagé',
    prix_demande    NUMERIC(10,2)   NOT NULL CHECK (prix_demande > 0),
    date_soumission DATE            NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT chk_etat CHECK (etat IN ('neuf', 'comme neuf', 'bon état', 'usagé', 'pour pièces'))
);

-- ============================================================
--  4. ANNONCE
--     Créée quand l'annonceur accepte l'estimation de l'expert.
--     Relation 1-1 avec PRODUIT (un produit → une annonce max).
--     Statut : en_attente | active | vendue | retiree
-- ============================================================
CREATE TABLE annonce (
    id_annonce      SERIAL          PRIMARY KEY,
    id_produit      INT             NOT NULL UNIQUE REFERENCES produit(id_produit) ON DELETE CASCADE,
    statut          VARCHAR(20)     NOT NULL DEFAULT 'en_attente',
    date_publication DATE,
    date_cloture    DATE,

    CONSTRAINT chk_statut_annonce CHECK (
        statut IN ('en_attente', 'active', 'vendue', 'retiree')
    ),
    CONSTRAINT chk_dates_annonce CHECK (
        date_cloture IS NULL OR date_publication IS NULL OR date_cloture >= date_publication
    )
);

-- ============================================================
--  5. ESTIMATION
--     Faite par un expert (utilisateur) sur une annonce.
--     decision_annonceur : NULL = pas encore décidé,
--                          'acceptee' ou 'refusee'
--     Invisible pour les acheteurs (géré côté applicatif).
-- ============================================================
CREATE TABLE estimation (
    id_estimation       SERIAL          PRIMARY KEY,
    id_produit          INT             NOT NULL REFERENCES produit(id_produit) ON DELETE CASCADE
    id_expert           INT             NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE RESTRICT,
    prix_estime         NUMERIC(10,2)   NOT NULL CHECK (prix_estime > 0),
    date_estimation     DATE            NOT NULL DEFAULT CURRENT_DATE,
    decision_annonceur  VARCHAR(10)     DEFAULT NULL,
    date_decision       DATE,

    CONSTRAINT chk_decision CHECK (
        decision_annonceur IS NULL OR decision_annonceur IN ('acceptee', 'refusee')
    ),
    CONSTRAINT chk_date_decision CHECK (
        date_decision IS NULL OR date_decision >= date_estimation
    )
);

-- ============================================================
--  6. PROPOSITION
--     Faite par un acheteur (utilisateur) sur une annonce active.
--     vente_conclue = TRUE si montant >= prix_estime (accepté).
--     Géré par trigger ou logique applicative Java.
-- ============================================================
CREATE TABLE proposition (
    id_proposition  SERIAL          PRIMARY KEY,
    id_annonce      INT             NOT NULL REFERENCES annonce(id_annonce)         ON DELETE CASCADE,
    id_acheteur     INT             NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE RESTRICT,
    montant         NUMERIC(10,2)   NOT NULL CHECK (montant > 0),
    date_proposition DATE           NOT NULL DEFAULT CURRENT_DATE,
    vente_conclue   BOOLEAN         NOT NULL DEFAULT FALSE
);

-- ============================================================
--  INDEX — améliore les performances des requêtes fréquentes
-- ============================================================
CREATE INDEX idx_produit_utilisateur   ON produit(id_utilisateur);
CREATE INDEX idx_produit_categorie     ON produit(id_categorie);
CREATE INDEX idx_annonce_statut        ON annonce(statut);
CREATE INDEX idx_estimation_annonce    ON estimation(id_annonce);
CREATE INDEX idx_estimation_expert     ON estimation(id_expert);
CREATE INDEX idx_proposition_annonce   ON proposition(id_annonce);
CREATE INDEX idx_proposition_acheteur  ON proposition(id_acheteur);

-- ============================================================
--  FIN DDL.sql
-- ============================================================
