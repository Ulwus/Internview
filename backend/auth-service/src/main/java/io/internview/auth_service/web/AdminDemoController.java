package io.internview.auth_service.web;

import java.util.Map;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AdminDemoController {

	@GetMapping("/admin/ping")
	@PreAuthorize("hasRole('ADMIN')")
	public ApiResponse<Map<String, String>> adminPing() {
		return ApiResponse.ok(Map.of("status", "ok"));
	}
}
