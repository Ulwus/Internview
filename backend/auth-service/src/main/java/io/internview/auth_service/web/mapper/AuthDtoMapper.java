package io.internview.auth_service.web.mapper;

import java.util.List;

import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import io.internview.auth_service.domain.User;
import io.internview.auth_service.web.dto.LoginResponseData;
import io.internview.auth_service.web.dto.MeResponseData;
import io.internview.auth_service.web.dto.RefreshResponseData;
import io.internview.auth_service.web.dto.RegisterResponseData;

@Mapper(componentModel = "spring")
public interface AuthDtoMapper {

	@Mapping(target = "userId", source = "user.id")
	@Mapping(target = "email", source = "user.email")
	@Mapping(target = "accessToken", source = "accessToken")
	@Mapping(target = "refreshToken", source = "refreshToken")
	@Mapping(target = "expiresIn", source = "expiresIn")
	RegisterResponseData toRegisterResponse(User user, String accessToken, String refreshToken, long expiresIn);

	@Mapping(target = "userId", source = "user.id")
	@Mapping(target = "accessToken", source = "accessToken")
	@Mapping(target = "refreshToken", source = "refreshToken")
	@Mapping(target = "expiresIn", source = "expiresIn")
	LoginResponseData toLoginResponse(User user, String accessToken, String refreshToken, long expiresIn);

	@Mapping(target = "accessToken", source = "accessToken")
	@Mapping(target = "expiresIn", source = "expiresIn")
	RefreshResponseData toRefreshResponse(String accessToken, long expiresIn);

	default MeResponseData toMeResponse(User user) {
		return MeResponseData.builder()
			.userId(user.getId())
			.email(user.getEmail())
			.firstName(user.getFirstName())
			.lastName(user.getLastName())
			.roles(List.of(user.getRole().name()))
			.build();
	}
}
