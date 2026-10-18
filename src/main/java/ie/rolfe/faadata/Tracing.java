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

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;

/**
 * Spans that group the loader's work: one for the whole run, with one per file
 * loaded under it, so the ClickHouse requests the OpenTelemetry agent traces
 * line up beneath them. Without the agent attached, these do nothing.
 */
final class Tracing {

    private static final Tracer TRACER = GlobalOpenTelemetry.getTracer("ie.rolfe.faadata");

    interface Body<T> {
        T run(Span span) throws Exception;
    }

    private Tracing() {
    }

    /** Runs {@code body} in a new span, a child of the current one, marking it failed if body throws. */
    static <T> T inSpan(String name, Body<T> body) throws Exception {
        Span span = TRACER.spanBuilder(name).startSpan();
        try (Scope ignored = span.makeCurrent()) {
            return body.run(span);
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, String.valueOf(e.getMessage()));
            throw e;
        } finally {
            span.end();
        }
    }
}
