package kijiji.db;

import kijiji.model.*;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class KijijiDAO {

    // ----------------------------------------------------------------
    //  AUTHENTIFICATION
    // ----------------------------------------------------------------

    public Utilisateur authentifier(String email, String motDePasse) throws SQLException {
        String sql = "SELECT * FROM utilisateur WHERE email = ? AND mot_de_passe = ?";
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sql)) {
            ps.setString(1, email);
            ps.setString(2, motDePasse);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return mapUtilisateur(rs);
        }
        return null;
    }

    // ----------------------------------------------------------------
    //  ANNONCES ACTIVES (vue acheteur)
    // ----------------------------------------------------------------

    public List<Annonce> getAnnoncesActives() throws SQLException {
        String sql = """
            SELECT a.id_annonce, p.titre, p.description, p.etat,
                   p.prix_demande, a.date_publication,
                   u.prenom || ' ' || u.nom AS vendeur,
                   c.nom AS categorie
            FROM   annonce a
            JOIN   produit p    ON p.id_produit    = a.id_produit
            JOIN   utilisateur u ON u.id_utilisateur = p.id_utilisateur
            JOIN   categorie c  ON c.id_categorie  = p.id_categorie
            WHERE  a.statut = 'active'
            ORDER  BY a.date_publication DESC
            """;
        List<Annonce> liste = new ArrayList<>();
        try (Statement st = Connexion.getInstance().createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) liste.add(mapAnnonce(rs));
        }
        return liste;
    }

    // ----------------------------------------------------------------
    //  PRODUITS D'UN ANNONCEUR
    // ----------------------------------------------------------------

    public List<Produit> getProduitsAnnonceur(int idUtilisateur) throws SQLException {
        String sql = """
            SELECT p.*, c.nom AS categorie,
                   a.id_annonce, a.statut AS statut_annonce,
                   e.prix_estime, e.decision_annonceur
            FROM   produit p
            JOIN   categorie c ON c.id_categorie = p.id_categorie
            LEFT JOIN annonce a    ON a.id_produit = p.id_produit
            LEFT JOIN estimation e ON e.id_annonce = a.id_annonce
            WHERE  p.id_utilisateur = ?
            ORDER  BY p.date_soumission DESC
            """;
        List<Produit> liste = new ArrayList<>();
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sql)) {
            ps.setInt(1, idUtilisateur);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) liste.add(mapProduit(rs));
        }
        return liste;
    }

    // ----------------------------------------------------------------
    //  SOUMETTRE UN PRODUIT
    // ----------------------------------------------------------------

    public int soumettreProduilt(int idUtilisateur, int idCategorie,
                                 String titre, String description,
                                 String etat, double prixDemande) throws SQLException {
        String sql = """
            INSERT INTO produit (id_utilisateur, id_categorie, titre,
                                 description, etat, prix_demande)
            VALUES (?, ?, ?, ?, ?, ?)
            RETURNING id_produit
            """;
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sql)) {
            ps.setInt(1, idUtilisateur);
            ps.setInt(2, idCategorie);
            ps.setString(3, titre);
            ps.setString(4, description);
            ps.setString(5, etat);
            ps.setDouble(6, prixDemande);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getInt(1);
        }
        return -1;
    }

    // ----------------------------------------------------------------
    //  CRÉER UNE ANNONCE (après soumission produit)
    // ----------------------------------------------------------------

    public int creerAnnonce(int idProduit) throws SQLException {
        String sql = """
            INSERT INTO annonce (id_produit, statut)
            VALUES (?, 'en_attente')
            RETURNING id_annonce
            """;
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sql)) {
            ps.setInt(1, idProduit);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) return rs.getInt(1);
        }
        return -1;
    }

    // ----------------------------------------------------------------
    //  SOUMETTRE UNE ESTIMATION (expert)
    // ----------------------------------------------------------------

    public void soumettreEstimation(int idAnnonce, int idExpert,
                                    double prixEstime) throws SQLException {
        String sql = """
            INSERT INTO estimation (id_annonce, id_expert, prix_estime)
            VALUES (?, ?, ?)
            """;
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sql)) {
            ps.setInt(1, idAnnonce);
            ps.setInt(2, idExpert);
            ps.setDouble(3, prixEstime);
            ps.executeUpdate();
        }
    }

    // ----------------------------------------------------------------
    //  DÉCISION ANNONCEUR (accepter / refuser estimation)
    // ----------------------------------------------------------------

    public void deciderEstimation(int idAnnonce, boolean accepter) throws SQLException {
        String decision = accepter ? "acceptee" : "refusee";
        String sqlEstimation = """
            UPDATE estimation
            SET    decision_annonceur = ?, date_decision = CURRENT_DATE
            WHERE  id_annonce = ?
            """;
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sqlEstimation)) {
            ps.setString(1, decision);
            ps.setInt(2, idAnnonce);
            ps.executeUpdate();
        }
        if (accepter) {
            String sqlAnnonce = """
                UPDATE annonce
                SET    statut = 'active', date_publication = CURRENT_DATE
                WHERE  id_annonce = ?
                """;
            try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sqlAnnonce)) {
                ps.setInt(1, idAnnonce);
                ps.executeUpdate();
            }
        } else {
            String sqlAnnonce = "UPDATE annonce SET statut = 'retiree' WHERE id_annonce = ?";
            try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sqlAnnonce)) {
                ps.setInt(1, idAnnonce);
                ps.executeUpdate();
            }
        }
    }

    // ----------------------------------------------------------------
    //  FAIRE UNE PROPOSITION (acheteur)
    // ----------------------------------------------------------------

    public boolean faireProposition(int idAnnonce, int idAcheteur,
                                    double montant) throws SQLException {
        // Récupérer le prix estimé accepté
        String sqlEstime = """
            SELECT prix_estime FROM estimation
            WHERE  id_annonce = ? AND decision_annonceur = 'acceptee'
            """;
        double prixEstime = -1;
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sqlEstime)) {
            ps.setInt(1, idAnnonce);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) prixEstime = rs.getDouble(1);
        }

        boolean venteConclue = (prixEstime > 0 && montant >= prixEstime);

        String sqlProp = """
            INSERT INTO proposition (id_annonce, id_acheteur, montant, vente_conclue)
            VALUES (?, ?, ?, ?)
            """;
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sqlProp)) {
            ps.setInt(1, idAnnonce);
            ps.setInt(2, idAcheteur);
            ps.setDouble(3, montant);
            ps.setBoolean(4, venteConclue);
            ps.executeUpdate();
        }

        if (venteConclue) {
            String sqlVendue = """
                UPDATE annonce
                SET    statut = 'vendue', date_cloture = CURRENT_DATE
                WHERE  id_annonce = ?
                """;
            try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sqlVendue)) {
                ps.setInt(1, idAnnonce);
                ps.executeUpdate();
            }
        }
        return venteConclue;
    }

    // ----------------------------------------------------------------
    //  PROPOSITIONS REÇUES SUR UNE ANNONCE
    // ----------------------------------------------------------------

    public List<Proposition> getPropositions(int idAnnonce) throws SQLException {
        String sql = """
            SELECT pr.*, u.prenom || ' ' || u.nom AS acheteur
            FROM   proposition pr
            JOIN   utilisateur u ON u.id_utilisateur = pr.id_acheteur
            WHERE  pr.id_annonce = ?
            ORDER  BY pr.date_proposition DESC
            """;
        List<Proposition> liste = new ArrayList<>();
        try (PreparedStatement ps = Connexion.getInstance().prepareStatement(sql)) {
            ps.setInt(1, idAnnonce);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) liste.add(mapProposition(rs));
        }
        return liste;
    }

    // ----------------------------------------------------------------
    //  CATÉGORIES
    // ----------------------------------------------------------------

    public List<Categorie> getCategories() throws SQLException {
        List<Categorie> liste = new ArrayList<>();
        try (Statement st = Connexion.getInstance().createStatement();
             ResultSet rs = st.executeQuery("SELECT * FROM categorie ORDER BY nom")) {
            while (rs.next())
                liste.add(new Categorie(rs.getInt("id_categorie"), rs.getString("nom")));
        }
        return liste;
    }

    // ----------------------------------------------------------------
    //  REQUÊTE RAPPORT — tableau de bord par catégorie (R10)
    // ----------------------------------------------------------------

    public ResultSet getTableauBordCategories() throws SQLException {
        String sql = """
            SELECT  c.nom AS categorie,
                    COUNT(DISTINCT a.id_annonce) AS nb_annonces,
                    COUNT(DISTINCT a.id_annonce)
                        FILTER (WHERE a.statut = 'vendue') AS nb_vendues,
                    ROUND(AVG(p.prix_demande), 2) AS prix_moyen,
                    ROUND(AVG(e.prix_estime), 2)  AS estime_moyen
            FROM    categorie c
            JOIN    produit p    ON p.id_categorie = c.id_categorie
            JOIN    annonce a    ON a.id_produit   = p.id_produit
            LEFT JOIN estimation e ON e.id_annonce = a.id_annonce
            GROUP   BY c.id_categorie, c.nom
            ORDER   BY nb_annonces DESC
            """;
        return Connexion.getInstance().createStatement().executeQuery(sql);
    }

    // ----------------------------------------------------------------
    //  MAPPERS
    // ----------------------------------------------------------------

    private Utilisateur mapUtilisateur(ResultSet rs) throws SQLException {
        return new Utilisateur(
            rs.getInt("id_utilisateur"),
            rs.getString("nom"),
            rs.getString("prenom"),
            rs.getString("email")
        );
    }

    private Annonce mapAnnonce(ResultSet rs) throws SQLException {
        return new Annonce(
            rs.getInt("id_annonce"),
            rs.getString("titre"),
            rs.getString("description"),
            rs.getString("etat"),
            rs.getDouble("prix_demande"),
            rs.getString("vendeur"),
            rs.getString("categorie"),
            rs.getDate("date_publication") != null
                ? rs.getDate("date_publication").toLocalDate() : null
        );
    }

    private Produit mapProduit(ResultSet rs) throws SQLException {
        return new Produit(
            rs.getInt("id_produit"),
            rs.getString("titre"),
            rs.getString("description"),
            rs.getString("etat"),
            rs.getDouble("prix_demande"),
            rs.getString("categorie"),
            rs.getInt("id_annonce"),
            rs.getString("statut_annonce"),
            rs.getObject("prix_estime")  != null ? rs.getDouble("prix_estime")  : null,
            rs.getString("decision_annonceur")
        );
    }

    private Proposition mapProposition(ResultSet rs) throws SQLException {
        return new Proposition(
            rs.getInt("id_proposition"),
            rs.getDouble("montant"),
            rs.getString("acheteur"),
            rs.getDate("date_proposition").toLocalDate(),
            rs.getBoolean("vente_conclue")
        );
    }
}
