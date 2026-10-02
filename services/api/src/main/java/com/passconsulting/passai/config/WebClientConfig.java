package com.passconsulting.passai.config;

import java.time.Duration;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;

import io.netty.channel.ChannelOption;
import reactor.netty.http.client.HttpClient;

@Configuration
public class WebClientConfig {

	@Bean
	WebClient.Builder webClientBuilder() {
		return WebClient.builder();
	}

	@Bean
	WebClient inferenceWebClient(WebClient.Builder webClientBuilder, PassAiProperties properties) {
		PassAiProperties.Inference inference = properties.inference();
		HttpClient httpClient = HttpClient.create()
				.responseTimeout(inference.readTimeout())
				.option(ChannelOption.CONNECT_TIMEOUT_MILLIS, (int) inference.connectTimeout().toMillis());

		WebClient.Builder builder = webClientBuilder
				.clone()
				.clientConnector(new ReactorClientHttpConnector(httpClient))
				.baseUrl(normalizeBaseUrl(inference.baseUrl()));

		if (inference.apiKey() != null && !inference.apiKey().isBlank()) {
			builder.defaultHeader("Authorization", "Bearer " + inference.apiKey());
		}
		return builder.build();
	}

	public static String normalizeBaseUrl(String baseUrl) {
		if (baseUrl == null || baseUrl.isBlank()) {
			return "http://127.0.0.1:30000/v1";
		}
		String trimmed = baseUrl.trim();
		return trimmed.endsWith("/") ? trimmed.substring(0, trimmed.length() - 1) : trimmed;
	}
}
