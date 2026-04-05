package io.internview.auth_service.web;

import com.fasterxml.jackson.annotation.JsonProperty;

public record ApiErrorBody(@JsonProperty("code") String code, @JsonProperty("message") String message) {
}
