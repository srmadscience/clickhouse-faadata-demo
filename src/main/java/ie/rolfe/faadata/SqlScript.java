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

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.clickhouse.client.api.Client;
import com.clickhouse.client.api.query.QueryResponse;
import com.clickhouse.client.api.query.QuerySettings;
import com.clickhouse.data.ClickHouseFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Runs the SQL a build script generates, in one process so the run is one trace.
 * The input is NUL-separated records (see sql_stmt, sql_span and sql_log in
 * scripts/lib.sh), each one of:
 *
 * <pre>
 *   a statement                     run, printing any result as ClickHouse sends it
 *                                   (TabSeparated unless the statement says FORMAT)
 *   --span NAME[\tKEY=VALUE]...     group the statements up to the next --span in
 *                                   a span called NAME, with those attributes; with
 *                                   no NAME, those that follow are in no step's span
 *   --log TEXT                      print TEXT
 * </pre>
 *
 * Stops at the first statement that fails.
 */
final class SqlScript {

    private static final Logger LOG = LoggerFactory.getLogger(SqlScript.class);
    private static final long TIMEOUT_MINUTES = 60;
    /** A trailing FORMAT clause. The client always sends a format, which overrides it, so it sends this one. */
    private static final Pattern FORMAT = Pattern.compile("(?is).*\\bFORMAT\\s+(\\w+)\\s*;?\\s*");

    /** Statements and messages, in order, under one span header (null for those before the first). */
    private record Step(String header, List<String> records) {
    }

    private SqlScript() {
    }

    static void run(Client client, InputStream in) throws Exception {
        List<Step> steps = new ArrayList<>();
        Step current = new Step(null, new ArrayList<>());
        for (String record : new String(in.readAllBytes(), StandardCharsets.UTF_8).split("\0")) {
            if (record.startsWith("--span ")) {
                String header = record.substring("--span ".length());
                steps.add(current);
                current = new Step(header.isEmpty() ? null : header, new ArrayList<>());
            } else if (!record.isBlank()) {
                current.records().add(record);
            }
        }
        steps.add(current);

        for (Step step : steps) {
            if (step.header() == null) {
                runAll(client, step.records());
                continue;
            }
            String[] parts = step.header().split("\t");
            Tracing.inSpan(parts[0], span -> {
                for (int i = 1; i < parts.length; i++) {
                    String[] kv = parts[i].split("=", 2);
                    span.setAttribute(kv[0], kv.length > 1 ? kv[1] : "");
                }
                runAll(client, step.records());
                return null;
            });
        }
    }

    private static void runAll(Client client, List<String> records) throws Exception {
        for (String record : records) {
            if (record.startsWith("--log ")) {
                LOG.info(record.substring("--log ".length()));
                continue;
            }
            Matcher format = FORMAT.matcher(record);
            QuerySettings settings = new QuerySettings().setFormat(
                    format.matches() ? ClickHouseFormat.valueOf(format.group(1)) : ClickHouseFormat.TabSeparated);
            try (QueryResponse response = client.query(record, settings).get(TIMEOUT_MINUTES, TimeUnit.MINUTES)) {
                response.getInputStream().transferTo(System.out);
            }
            System.out.flush();
        }
    }
}
