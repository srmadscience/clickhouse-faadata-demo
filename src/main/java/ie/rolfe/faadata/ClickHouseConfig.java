package ie.rolfe.faadata;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

import com.clickhouse.client.api.Client;

/**
 * Connection settings for the ClickHouse server.
 * <p>
 * Values are resolved in this order: environment variable, then
 * {@code ./clickhouse.properties} (git-ignored), then built-in default.
 * Credentials must never be committed.
 */
public record ClickHouseConfig(String endpoint, String user, String password, String database) {

    private static final String LOCAL_PROPS = "clickhouse.properties";

    public static ClickHouseConfig load() {
        Properties props = new Properties();
        Path local = Path.of(LOCAL_PROPS);
        if (Files.isReadable(local)) {
            try (InputStream in = Files.newInputStream(local)) {
                props.load(in);
            } catch (IOException e) {
                throw new IllegalStateException("Unable to read " + local.toAbsolutePath(), e);
            }
        }
        return new ClickHouseConfig(
                resolve(props, "CLICKHOUSE_URL", "clickhouse.url", "http://xraytunnel:8123"),
                resolve(props, "CLICKHOUSE_USER", "clickhouse.user", "default"),
                resolve(props, "CLICKHOUSE_PASSWORD", "clickhouse.password", ""),
                resolve(props, "CLICKHOUSE_DATABASE", "clickhouse.database", "faa"));
    }

    private static String resolve(Properties props, String envName, String propName, String dflt) {
        String env = System.getenv(envName);
        if (env != null && !env.isBlank()) {
            return env;
        }
        return props.getProperty(propName, dflt);
    }

    public Client newClient() {
        return new Client.Builder()
                .addEndpoint(endpoint)
                .setUsername(user)
                .setPassword(password)
                .setDefaultDatabase(database)
                // Standard HTTP Content-Encoding rather than ClickHouse's native
                // framing: xraytunnel uses ZSTD network compression, which the
                // client's native decoder (LZ4 only) can't read.
                .useHttpCompression(true)
                // Uploads go uncompressed: the client's pure-Java LZ4 encoder
                // manages ~0.3 MB/s, far slower than the LAN to xraytunnel.
                .compressClientRequest(false)
                .build();
    }
}
