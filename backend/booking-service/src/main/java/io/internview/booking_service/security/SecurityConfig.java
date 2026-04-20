package io.internview.booking_service.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.SecurityFilterChain;

import lombok.RequiredArgsConstructor;

@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

	private final JwtDecoder jwtDecoder;
	private final Converter<Jwt, AbstractAuthenticationToken> jwtAuthenticationConverter;

	@Bean
	SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
		http.csrf(AbstractHttpConfigurer::disable);
		http.sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
		http.authorizeHttpRequests(auth -> auth
			.requestMatchers("/actuator/health", "/actuator/info").permitAll()
			.requestMatchers(org.springframework.http.HttpMethod.GET, "/availability/*").permitAll()
			.anyRequest().authenticated());
		http.oauth2ResourceServer(oauth2 -> oauth2
			.jwt(jwt -> jwt.decoder(this.jwtDecoder).jwtAuthenticationConverter(this.jwtAuthenticationConverter)));
		return http.build();
	}
}
