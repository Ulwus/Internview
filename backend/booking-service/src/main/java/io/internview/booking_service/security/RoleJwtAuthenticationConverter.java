package io.internview.booking_service.security;

import java.util.Collection;
import java.util.Collections;

import org.springframework.core.convert.converter.Converter;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
public class RoleJwtAuthenticationConverter implements Converter<Jwt, AbstractAuthenticationToken> {

	@Override
	public AbstractAuthenticationToken convert(@NonNull Jwt jwt) {
		String role = jwt.getClaimAsString("role");
		Collection<SimpleGrantedAuthority> authorities = (role == null || role.isBlank())
			? Collections.emptyList()
			: Collections.singletonList(new SimpleGrantedAuthority("ROLE_" + role));
		return new JwtAuthenticationToken(jwt, authorities);
	}
}
