package io.internview.gateway.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.factory.AbstractGatewayFilterFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;

import reactor.core.publisher.Mono;

@Component
public class BasicAuthGatewayFilterFactory extends AbstractGatewayFilterFactory<BasicAuthGatewayFilterFactory.Config> {

    private final String expectedUser;
    private final String expectedPassword;

    public BasicAuthGatewayFilterFactory(
            @Value("${gateway.security.basic-auth.user}") String expectedUser,
            @Value("${gateway.security.basic-auth.password}") String expectedPassword
    ) {
        super(Config.class);
        this.expectedUser = expectedUser;
        this.expectedPassword = expectedPassword;
    }

    public static class Config {
        // route filter olarak parametre almıyoruz; cred'ler config/env'den geliyor.
    }

    @Override
    public GatewayFilter apply(Config config) {
        return (exchange, chain) -> {
            String authHeader = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
            if (authHeader == null || !authHeader.startsWith("Basic ")) {
                return unauthorized(exchange);
            }

            String base64 = authHeader.substring("Basic ".length()).trim();
            String decoded;
            try {
                decoded = new String(Base64.getDecoder().decode(base64), StandardCharsets.UTF_8);
            } catch (IllegalArgumentException e) {
                return unauthorized(exchange);
            }

            int idx = decoded.indexOf(':');
            if (idx <= 0) {
                return unauthorized(exchange);
            }

            String user = decoded.substring(0, idx);
            String password = decoded.substring(idx + 1);

            if (!constantTimeEquals(user, expectedUser) || !constantTimeEquals(password, expectedPassword)) {
                return unauthorized(exchange);
            }

            return chain.filter(exchange);
        };
    }

    private static Mono<Void> unauthorized(ServerWebExchange exchange) {
        exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
        exchange.getResponse().getHeaders().set(HttpHeaders.WWW_AUTHENTICATE, "Basic realm=\"gateway\"");
        exchange.getResponse().getHeaders().setContentType(MediaType.APPLICATION_JSON);
        byte[] body = "{\"error\":\"unauthorized\"}".getBytes(StandardCharsets.UTF_8);
        return exchange.getResponse().writeWith(Mono.just(exchange.getResponse().bufferFactory().wrap(body)));
    }

    private static boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        byte[] aBytes = a.getBytes(StandardCharsets.UTF_8);
        byte[] bBytes = b.getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(aBytes, bBytes);
    }
}

