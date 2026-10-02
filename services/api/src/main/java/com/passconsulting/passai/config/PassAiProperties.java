package com.passconsulting.passai.config;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "pass.ai")
public record PassAiProperties(Db db, Security security, Inference inference) {

	public record Db(boolean enabled) {
	}

	public record Security(String apiKey) {
		public boolean isProtectionEnabled() {
			return apiKey != null && !apiKey.isBlank();
		}
	}

	public record Inference(
			String baseUrl,
			String apiKey,
			String adminUrl,
			Duration connectTimeout,
			Duration readTimeout,
			String defaultModel) {
	}
}
