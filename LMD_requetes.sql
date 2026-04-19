-- ============================================================
--  LMD_requetes.sql  —  10 requêtes SQL
--  Système de vente type Kijiji
-- ============================================================

-- ============================================================
--  REQUÊTES SIMPLES (1 à 5)  —  1 à 3 tables
-- ============================================================

-- ------------------------------------------------------------
--  R1 : Liste de toutes les annonces actives avec le titre
--       du produit et le prix demandé, triées par prix desc.
--  Tables : annonce, produit
--  Résultat attendu : toutes les annonces dont statut = 'active',
--  affichant le titre et le prix demandé par l'annonceur.
-- ------------------------------------------------------------
SELECT  a.id_annonce,
        p.titre,
        p.etat,
        p.prix_demande,
        a.date_publication
FROM    annonce  a
JOIN    produit  p ON p.id_produit = a.id_produit
WHERE   a.statut = 'active'
ORDER BY p.prix_demande DESC;


-- ------------------------------------------------------------
--  R2 : Nombre de produits soumis par catégorie, trié du
--       plus au moins populaire.
--  Tables : produit, categorie
--  Résultat attendu : chaque catégorie avec le nombre de
--  produits qui lui sont associés.
-- ------------------------------------------------------------
SELECT  c.nom            AS categorie,
        COUNT(p.id_produit) AS nb_produits
FROM    categorie c
LEFT JOIN produit p ON p.id_categorie = c.id_categorie
GROUP BY c.id_categorie, c.nom
ORDER BY nb_produits DESC;


-- ------------------------------------------------------------
--  R3 : Toutes les propositions reçues pour une annonce
--       donnée (ici annonce #2), avec le montant et la date.
--  Tables : proposition, utilisateur
--  Résultat attendu : liste des offres faites sur l'annonce 2,
--  avec le nom de l'acheteur, le montant et si vente conclue.
-- ------------------------------------------------------------
SELECT  u.prenom || ' ' || u.nom  AS acheteur,
        pr.montant,
        pr.date_proposition,
        pr.vente_conclue
FROM    proposition  pr
JOIN    utilisateur  u ON u.id_utilisateur = pr.id_acheteur
WHERE   pr.id_annonce = 2
ORDER BY pr.date_proposition;


-- ------------------------------------------------------------
--  R4 : Utilisateurs qui ont à la fois posté un produit
--       (annonceur) ET fait une proposition (acheteur).
--  Tables : produit, proposition, utilisateur
--  Résultat attendu : utilisateurs avec les deux rôles actifs
--  — illustre la contrainte multi-rôles du système.
-- ------------------------------------------------------------
SELECT  u.id_utilisateur,
        u.prenom || ' ' || u.nom  AS nom_complet,
        u.email
FROM    utilisateur u
WHERE   EXISTS (
            SELECT 1 FROM produit    WHERE id_utilisateur = u.id_utilisateur
        )
AND     EXISTS (
            SELECT 1 FROM proposition WHERE id_acheteur  = u.id_utilisateur
        )
ORDER BY u.nom;


-- ------------------------------------------------------------
--  R5 : Estimations encore en attente de décision
--       (decision_annonceur IS NULL).
--  Tables : estimation, annonce, utilisateur
--  Résultat attendu : liste des estimations soumises par
--  l'expert mais pas encore acceptées ni refusées.
-- ------------------------------------------------------------
SELECT  e.id_estimation,
        u.prenom || ' ' || u.nom  AS expert,
        e.prix_estime,
        e.date_estimation,
        a.id_annonce
FROM    estimation   e
JOIN    utilisateur  u ON u.id_utilisateur = e.id_expert
JOIN    annonce      a ON a.id_annonce     = e.id_annonce
WHERE   e.decision_annonceur IS NULL
ORDER BY e.date_estimation;


-- ============================================================
--  REQUÊTES COMPLEXES (6 à 10)  —  4 relations minimum
-- ============================================================

-- ------------------------------------------------------------
--  R6 : Pour chaque annonce vendue, afficher le vendeur,
--       l'acheteur gagnant, le produit, le prix estimé et
--       le montant final de la vente.
--  Tables : annonce, produit, utilisateur (vendeur),
--           estimation, proposition, utilisateur (acheteur)
--  Résultat attendu : résumé complet des transactions conclues.
-- ------------------------------------------------------------
SELECT  prd.titre                             AS produit,
        v.prenom  || ' ' || v.nom             AS vendeur,
        ach.prenom || ' ' || ach.nom          AS acheteur,
        e.prix_estime                         AS prix_expert,
        pr.montant                            AS prix_final,
        pr.date_proposition                   AS date_vente
FROM    annonce      a
JOIN    produit      prd ON prd.id_produit    = a.id_produit
JOIN    utilisateur  v   ON v.id_utilisateur  = prd.id_utilisateur
JOIN    estimation   e   ON e.id_annonce      = a.id_annonce
JOIN    proposition  pr  ON pr.id_annonce     = a.id_annonce
JOIN    utilisateur  ach ON ach.id_utilisateur = pr.id_acheteur
WHERE   a.statut        = 'vendue'
AND     pr.vente_conclue = TRUE
ORDER BY pr.date_proposition;


-- ------------------------------------------------------------
--  R7 : Annonceurs les plus actifs : nombre d'annonces,
--       valeur totale des produits soumis, et montant total
--       des ventes conclues.
--  Tables : utilisateur, produit, annonce,
--           estimation, proposition
--  Résultat attendu : classement des annonceurs par valeur
--  totale de ventes conclues.
-- ------------------------------------------------------------
SELECT  u.prenom || ' ' || u.nom          AS annonceur,
        COUNT(DISTINCT prd.id_produit)    AS nb_produits,
        SUM(prd.prix_demande)             AS valeur_totale_demandee,
        COALESCE(SUM(pr.montant)
            FILTER (WHERE pr.vente_conclue = TRUE), 0)
                                          AS revenus_ventes
FROM    utilisateur  u
JOIN    produit      prd ON prd.id_utilisateur = u.id_utilisateur
JOIN    annonce      a   ON a.id_produit       = prd.id_produit
LEFT JOIN estimation e   ON e.id_annonce       = a.id_annonce
LEFT JOIN proposition pr ON pr.id_annonce      = a.id_annonce
GROUP BY u.id_utilisateur, u.nom, u.prenom
HAVING  COUNT(DISTINCT prd.id_produit) > 0
ORDER BY revenus_ventes DESC;


-- ------------------------------------------------------------
--  R8 : Produits dont le prix demandé par l'annonceur est
--       supérieur de plus de 20% au prix estimé par l'expert
--       (annonceur trop optimiste), avec la catégorie.
--  Tables : produit, annonce, estimation,
--           categorie, utilisateur
--  Résultat attendu : liste des produits surévalués par
--  rapport à l'estimation de marché.
-- ------------------------------------------------------------
SELECT  u.prenom || ' ' || u.nom   AS annonceur,
        c.nom                      AS categorie,
        prd.titre,
        prd.prix_demande,
        e.prix_estime,
        ROUND((prd.prix_demande - e.prix_estime)
              / e.prix_estime * 100, 1)  AS surplus_pct
FROM    produit      prd
JOIN    utilisateur  u   ON u.id_utilisateur  = prd.id_utilisateur
JOIN    categorie    c   ON c.id_categorie    = prd.id_categorie
JOIN    annonce      a   ON a.id_produit      = prd.id_produit
JOIN    estimation   e   ON e.id_annonce      = a.id_annonce
WHERE   prd.prix_demande > e.prix_estime * 1.20
ORDER BY surplus_pct DESC;


-- ------------------------------------------------------------
--  R9 : Experts les plus sollicités : nombre d'estimations
--       effectuées, taux d'acceptation par les annonceurs,
--       et écart moyen entre prix estimé et prix de vente.
--  Tables : utilisateur, estimation, annonce,
--           proposition, produit
--  Résultat attendu : performance et fiabilité de chaque
--  expert selon les décisions des annonceurs.
-- ------------------------------------------------------------
SELECT  u.prenom || ' ' || u.nom              AS expert,
        COUNT(e.id_estimation)                AS nb_estimations,
        ROUND(
            COUNT(e.id_estimation)
            FILTER (WHERE e.decision_annonceur = 'acceptee')
            * 100.0 / COUNT(e.id_estimation), 1
        )                                     AS taux_acceptation_pct,
        ROUND(AVG(
            CASE WHEN pr.vente_conclue = TRUE
                 THEN pr.montant - e.prix_estime
            END
        ), 2)                                 AS ecart_moyen_vente
FROM    utilisateur  u
JOIN    estimation   e   ON e.id_expert    = u.id_utilisateur
JOIN    annonce      a   ON a.id_annonce   = e.id_annonce
JOIN    produit      prd ON prd.id_produit = a.id_produit
LEFT JOIN proposition pr ON pr.id_annonce  = e.id_annonce
                        AND pr.vente_conclue = TRUE
GROUP BY u.id_utilisateur, u.nom, u.prenom
ORDER BY nb_estimations DESC;


-- ------------------------------------------------------------
--  R10 : Pour chaque catégorie, statistiques complètes :
--        nb annonces, nb vendues, taux de vente, prix moyen
--        demandé, prix moyen estimé, et montant moyen des
--        ventes conclues.
--  Tables : categorie, produit, annonce,
--           estimation, proposition
--  Résultat attendu : tableau de bord par catégorie pour
--  analyser les performances du marché.
-- ------------------------------------------------------------
SELECT  c.nom                                           AS categorie,
        COUNT(DISTINCT a.id_annonce)                    AS nb_annonces,
        COUNT(DISTINCT a.id_annonce)
            FILTER (WHERE a.statut = 'vendue')          AS nb_vendues,
        ROUND(
            COUNT(DISTINCT a.id_annonce)
            FILTER (WHERE a.statut = 'vendue')
            * 100.0 / NULLIF(COUNT(DISTINCT a.id_annonce), 0)
        , 1)                                            AS taux_vente_pct,
        ROUND(AVG(prd.prix_demande), 2)                 AS prix_moyen_demande,
        ROUND(AVG(e.prix_estime), 2)                    AS prix_moyen_estime,
        ROUND(AVG(pr.montant)
            FILTER (WHERE pr.vente_conclue = TRUE), 2)  AS montant_moyen_vente
FROM    categorie    c
JOIN    produit      prd ON prd.id_categorie = c.id_categorie
JOIN    annonce      a   ON a.id_produit     = prd.id_produit
LEFT JOIN estimation e   ON e.id_annonce     = a.id_annonce
LEFT JOIN proposition pr ON pr.id_annonce    = a.id_annonce
GROUP BY c.id_categorie, c.nom
ORDER BY nb_annonces DESC;

-- ============================================================
--  FIN LMD_requetes.sql
-- ============================================================
