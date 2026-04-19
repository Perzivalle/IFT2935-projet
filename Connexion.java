package kijiji.db;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class Connexion {

    private static final String URL      = "jdbc:postgresql://localhost:5432/kijiji_db";
    private static final String USER     = "postgres";
    private static final String PASSWORD = "postgres";

    private static Connection instance = null;

    private Connexion() {}

    public static Connection getInstance() throws SQLException {
        if (instance == null || instance.isClosed()) {
            instance = DriverManager.getConnection(URL, USER, PASSWORD);
        }
        return instance;
    }

    public static void fermer() {
        try {
            if (instance != null && !instance.isClosed()) {
                instance.close();
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}
