package io.internview.gateway.logging;

import java.time.Duration;
import java.util.Optional;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.route.Route;
import org.springframework.core.Ordered;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;

import reactor.core.publisher.Mono;

import static org.springframework.cloud.gateway.support.ServerWebExchangeUtils.GATEWAY_ROUTE_ATTR;

@Component
public class GatewayRequestResponseLoggingFilter implements GlobalFilter, Ordered {
    private static final Logger log = LoggerFactory.getLogger(GatewayRequestResponseLoggingFilter.class);

    private static final String CORRELATION_ID_HEADER = "X-Correlation-Id";
    private static final String REQUEST_ID_HEADER = "X-Request-Id";

    @Override
    public int getOrder() {
        // Route seçimi sonrası çalışması için çok erken olmamasını tercih ediyoruz.
        return -1;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        long startNanos = System.nanoTime();

        ServerHttpRequest request = exchange.getRequest();
        String correlationId = resolveCorrelationId(request);

        // Correlation id'yi upstream'e ve response'a taşı.
        ServerWebExchange mutatedExchange = exchange.mutate()
                .request(builder -> builder.header(CORRELATION_ID_HEADER, correlationId))
                .build();
        mutatedExchange.getResponse().getHeaders().set(CORRELATION_ID_HEADER, correlationId);

        String method = request.getMethod() != null ? request.getMethod().name() : "UNKNOWN";
        String path = request.getURI().getRawPath();
        String query = request.getURI().getRawQuery();
        String fullPath = query == null || query.isBlank() ? path : path + "?" + query;

        log.info("gateway.request id={} method={} path={}", correlationId, method, fullPath);

        return chain.filter(mutatedExchange)
                .doFinally(signalType -> {
                    Duration latency = Duration.ofNanos(System.nanoTime() - startNanos);
                    HttpStatusCode status = mutatedExchange.getResponse().getStatusCode();
                    String statusValue = status != null ? Integer.toString(status.value()) : "NA";
                    String routeId = Optional.ofNullable(mutatedExchange.getAttribute(GATEWAY_ROUTE_ATTR))
                            .filter(Route.class::isInstance)
                            .map(Route.class::cast)
                            .map(Route::getId)
                            .orElse("NA");

                    log.info(
                            "gateway.response id={} status={} latencyMs={} route={}",
                            correlationId,
                            statusValue,
                            latency.toMillis(),
                            routeId
                    );
                });
    }

    private static String resolveCorrelationId(ServerHttpRequest request) {
        String correlationId = request.getHeaders().getFirst(CORRELATION_ID_HEADER);
        if (correlationId != null && !correlationId.isBlank()) {
            return correlationId;
        }
        String requestId = request.getHeaders().getFirst(REQUEST_ID_HEADER);
        if (requestId != null && !requestId.isBlank()) {
            return requestId;
        }
        return UUID.randomUUID().toString();
    }
}

