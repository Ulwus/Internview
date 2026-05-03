package io.internview.interview_service.signaling.error;

import lombok.Getter;

@Getter
public class SignalingException extends RuntimeException {

	private final String code;

	public SignalingException(String code, String message) {
		super(message);
		this.code = code;
	}

	public SignalingException(String code, String message, Throwable cause) {
		super(message, cause);
		this.code = code;
	}
}
