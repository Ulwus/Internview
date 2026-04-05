package io.internview.auth_service.error;

import lombok.experimental.StandardException;

@StandardException
public class InvalidRefreshTokenException extends RuntimeException {
}
