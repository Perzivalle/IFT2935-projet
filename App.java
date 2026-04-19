package kijiji;

import javafx.application.Application;
import javafx.stage.Stage;
import kijiji.db.Connexion;
import kijiji.db.KijijiDAO;
import kijiji.ui.LoginView;

public class App extends Application {

    @Override
    public void start(Stage primaryStage) {
        KijijiDAO dao = new KijijiDAO();
        new LoginView(primaryStage, dao).afficher();
    }

    @Override
    public void stop() {
        Connexion.fermer();
    }

    public static void main(String[] args) {
        launch(args);
    }
}
