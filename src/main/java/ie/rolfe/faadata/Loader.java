/*
 * Copyright 2026 David Rolfe
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package ie.rolfe.faadata;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.FilterInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.SequenceInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;
import java.util.zip.GZIPInputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import com.clickhouse.client.api.Client;
import com.clickhouse.client.api.insert.InsertResponse;
import com.clickhouse.client.api.insert.InsertSettings;
import com.clickhouse.data.ClickHouseFormat;

/**
 * Command-line entry point.
 *
 * <pre>
 *   ping                          check connectivity and print the server version
 *   schema &lt;file.sql&gt;...          run ';'-separated DDL statements
 *   load &lt;table&gt; [--set k=v]... [--combine] &lt;path&gt;...
 *                                 stream CSV files (plain, .gz or .zip) into a table,
 *                                 applying ClickHouse settings to each insert
 * </pre>
 *
 * Files are streamed straight from disk to ClickHouse, so memory use is
 * independent of file size. Each file is one insert, unless --combine is given:
 * then all the plain or .gz files under each path go in one insert, which is much
 * faster for many small files. Their header lines must be identical.
 */
public class Loader {

    private static final long TIMEOUT_MINUTES = 60;

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            usage();
            return;
        }
        ClickHouseConfig config = ClickHouseConfig.load();
        try (Client client = config.newClient()) {
            switch (args[0]) {
                case "ping" -> ping(client, config);
                case "schema" -> schema(client, List.of(args).subList(1, args.length));
                case "load" -> {
                    if (args.length < 3) {
                        usage();
                        System.exit(1);
                    }
                    load(client, args[1], List.of(args).subList(2, args.length));
                }
                default -> {
                    usage();
                    System.exit(1);
                }
            }
        }
    }

    private static void usage() {
        System.err.println("usage: Loader ping | schema <file.sql>... | load <table> [--set k=v]... [--combine] <file-or-dir>...");
    }

    private static void ping(Client client, ClickHouseConfig config) throws Exception {
        var records = client.queryAll("SELECT version()");
        System.out.println("Connected to " + config.endpoint() + " as " + config.user()
                + ", ClickHouse " + records.get(0).getString(1));
    }

    private static void schema(Client client, List<String> files) throws Exception {
        for (String file : files) {
            for (String stmt : Files.readString(Path.of(file)).split(";")) {
                String sql = stripComments(stmt).strip();
                if (!sql.isEmpty()) {
                    System.out.println("Executing: " + sql.lines().findFirst().orElse(""));
                    client.execute(sql).get(TIMEOUT_MINUTES, TimeUnit.MINUTES).close();
                }
            }
        }
    }

    private static String stripComments(String sql) {
        return sql.lines().filter(l -> !l.strip().startsWith("--")).reduce("", (a, b) -> a + b + "\n");
    }

    private static void load(Client client, String table, List<String> args) throws Exception {
        InsertSettings settings = new InsertSettings();
        List<String> paths = new ArrayList<>();
        boolean combine = false;
        for (int i = 0; i < args.size(); i++) {
            if (args.get(i).equals("--combine")) {
                combine = true;
            } else if (args.get(i).equals("--set") && i + 1 < args.size()) {
                String[] kv = args.get(++i).split("=", 2);
                if (kv.length != 2) {
                    throw new IllegalArgumentException("--set expects key=value, got " + args.get(i));
                }
                settings.serverSetting(kv[0], kv[1]);
            } else {
                paths.add(args.get(i));
            }
        }
        long totalRows = 0;
        if (combine) {
            for (String path : paths) {
                List<Path> files = expand(List.of(path));
                long start = System.nanoTime();
                long rows = insert(client, table, new ConcatenatedCsv(files), settings);
                totalRows += rows;
                System.out.printf("%s (%,d files) -> %s: %,d rows in %.1fs%n",
                        path, files.size(), table, rows, (System.nanoTime() - start) / 1e9);
            }
            System.out.printf("Total: %,d rows%n", totalRows);
            return;
        }
        for (Path file : expand(paths)) {
            long start = System.nanoTime();
            long rows = loadFile(client, table, file, settings);
            totalRows += rows;
            System.out.printf("%s -> %s: %,d rows in %.1fs%n",
                    file, table, rows, (System.nanoTime() - start) / 1e9);
        }
        System.out.printf("Total: %,d rows%n", totalRows);
    }

    private static long loadFile(Client client, String table, Path file, InsertSettings settings) throws Exception {
        String name = file.getFileName().toString().toLowerCase();
        try (InputStream raw = Files.newInputStream(file)) {
            if (name.endsWith(".zip")) {
                // e.g. BTS on-time downloads: one CSV inside each zip
                long rows = 0;
                try (ZipInputStream zip = new ZipInputStream(raw)) {
                    ZipEntry entry;
                    while ((entry = zip.getNextEntry()) != null) {
                        if (!entry.isDirectory() && entry.getName().toLowerCase().endsWith(".csv")) {
                            rows += insert(client, table, new NonClosingInputStream(zip), settings);
                        }
                    }
                }
                return rows;
            }
            InputStream in = name.endsWith(".gz") ? new GZIPInputStream(raw, 1 << 16) : raw;
            return insert(client, table, in, settings);
        }
    }

    private static long insert(Client client, String table, InputStream in, InsertSettings settings) throws Exception {
        try (InsertResponse response = client.insert(table, in, ClickHouseFormat.CSVWithNames, settings)
                .get(TIMEOUT_MINUTES, TimeUnit.MINUTES)) {
            return response.getWrittenRows();
        }
    }

    private static List<Path> expand(List<String> paths) throws IOException {
        List<Path> files = new ArrayList<>();
        for (String p : paths) {
            Path path = Path.of(p);
            if (Files.isDirectory(path)) {
                try (Stream<Path> s = Files.walk(path)) {
                    s.filter(Files::isRegularFile)
                            .filter(f -> !f.getFileName().toString().startsWith("."))
                            .sorted()
                            .forEach(files::add);
                }
            } else {
                files.add(path);
            }
        }
        return files;
    }

    private static InputStream open(Path file) throws IOException {
        InputStream raw = Files.newInputStream(file);
        return file.getFileName().toString().toLowerCase().endsWith(".gz") ? new GZIPInputStream(raw, 1 << 16) : raw;
    }

    /**
     * Several CSV files read as one: the first file's header line, then every
     * file's data lines. Files are opened one at a time, as they are reached.
     */
    private static final class ConcatenatedCsv extends InputStream {
        private final Iterator<Path> files;
        private byte[] header;
        private Path current;
        private InputStream in = InputStream.nullInputStream();
        private int last = '\n';

        ConcatenatedCsv(List<Path> files) {
            this.files = files.iterator();
        }

        @Override
        public int read() throws IOException {
            byte[] b = new byte[1];
            return read(b, 0, 1) < 0 ? -1 : b[0] & 0xff;
        }

        @Override
        public int read(byte[] b, int off, int len) throws IOException {
            if (len == 0) {
                return 0;
            }
            while (true) {
                int n = in.read(b, off, len);
                if (n > 0) {
                    last = b[off + n - 1];
                    return n;
                }
                if (last != '\n') {
                    // the file just finished had no final newline
                    last = '\n';
                    b[off] = '\n';
                    return 1;
                }
                in.close();
                if (!files.hasNext()) {
                    return -1;
                }
                current = files.next();
                in = open(current);
                byte[] line = readLine(in);
                if (header == null) {
                    header = line;
                    in = new SequenceInputStream(new ByteArrayInputStream(line), in);
                } else if (!Arrays.equals(line, header)) {
                    throw new IOException(current + ": header differs from the first file's");
                }
            }
        }

        private static byte[] readLine(InputStream in) throws IOException {
            ByteArrayOutputStream line = new ByteArrayOutputStream();
            int c;
            while ((c = in.read()) >= 0) {
                line.write(c);
                if (c == '\n') {
                    break;
                }
            }
            return line.toByteArray();
        }

        @Override
        public void close() throws IOException {
            in.close();
        }
    }

    /** Stops the client from closing a ZipInputStream between entries. */
    private static final class NonClosingInputStream extends FilterInputStream {
        NonClosingInputStream(InputStream in) {
            super(in);
        }

        @Override
        public void close() {
            // intentionally empty
        }
    }
}
