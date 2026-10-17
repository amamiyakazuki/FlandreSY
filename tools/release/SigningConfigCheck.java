import java.nio.file.Files;
import java.nio.file.Path;
import java.io.InputStream;
import java.util.Properties;

/** Uses the same Java Properties and android-relative path semantics as Gradle.
 * Never prints passwords, aliases or private filesystem paths. */
class SigningConfigCheck {
    public static void main(String[] args) {
        try {
            Path android = Path.of(args[0]).toAbsolutePath();
            Properties values = new Properties();
            try (InputStream input = Files.newInputStream(android.resolve("key.properties"))) {
                values.load(input);
            }
            for (String key : new String[]{"storeFile", "storePassword", "keyAlias", "keyPassword"}) {
                if (values.getProperty(key, "").isBlank()) throw new IllegalArgumentException();
            }
            Path file = Path.of(values.getProperty("storeFile"));
            if (!file.isAbsolute()) file = android.resolve(file);
            if (!Files.isRegularFile(file)) throw new IllegalArgumentException();
            System.out.println("Signing configuration is complete (key not opened).");
        } catch (Exception error) {
            System.err.println("Invalid signing configuration: check android/key.properties and keystore existence.");
            System.exit(1);
        }
    }
}
