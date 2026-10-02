package com.passconsulting.passai.inference;

import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.core.io.ClassPathResource;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.passconsulting.passai.config.PassAiProperties;

@Service
public class ModelCatalogService {

	private final ObjectMapper objectMapper;
	private final PassAiProperties properties;
	private final WebClient.Builder webClientBuilder;

	private List<CatalogModel> cachedCatalog;

	public ModelCatalogService(ObjectMapper objectMapper, PassAiProperties properties, WebClient.Builder webClientBuilder) {
		this.objectMapper = objectMapper;
		this.properties = properties;
		this.webClientBuilder = webClientBuilder;
	}

	public synchronized List<CatalogModel> catalog() {
		if (cachedCatalog != null) {
			return cachedCatalog;
		}
		Optional<List<CatalogModel>> remote = fetchRemoteCatalog();
		if (remote.isPresent()) {
			cachedCatalog = remote.get();
			return cachedCatalog;
		}
		cachedCatalog = loadClasspathCatalog();
		return cachedCatalog;
	}

	public String openAiModelsJson() {
		List<CatalogModel> models = catalog();
		String active = activeModelId().orElse(models.isEmpty() ? "" : models.get(0).id());
		StringBuilder data = new StringBuilder();
		for (CatalogModel model : models) {
			boolean isActive = model.id().equals(active);
			data.append("""
					{"id":"%s","object":"model","owned_by":"pass-ai","pass_ai":{"displayName":"%s","tier":"%s","contextLength":%d,"active":%s}}
					,""".formatted(
					escapeJson(model.id()),
					escapeJson(model.displayName()),
					escapeJson(model.tier()),
					model.contextLength(),
					isActive));
		}
		if (data.length() > 0) {
			data.setLength(data.length() - 1);
		}
		return "{\"object\":\"list\",\"data\":[" + data + "]}";
	}

	public Optional<String> activeModelId() {
		String adminUrl = properties.inference().adminUrl();
		if (adminUrl == null || adminUrl.isBlank()) {
			return Optional.empty();
		}
		try {
			WebClient client = adminClient(adminUrl);
			String body = client.get().uri("/v1/active").retrieve().bodyToMono(String.class).block();
			if (body == null) {
				return Optional.empty();
			}
			JsonNode node = objectMapper.readTree(body);
			return Optional.ofNullable(node.path("modelId").asText(null));
		}
		catch (Exception ex) {
			return Optional.empty();
		}
	}

	public void ensureActiveModel(String requestedModelId) {
		if (requestedModelId == null || requestedModelId.isBlank()) {
			return;
		}
		String clean = requestedModelId.trim();
		Optional<String> active = activeModelId();
		if (active.isPresent() && active.get().equals(clean)) {
			return;
		}
		boolean inCatalog = catalog().stream().anyMatch(m -> m.id().equals(clean));
		if (!inCatalog) {
			return;
		}
		String adminUrl = properties.inference().adminUrl();
		if (adminUrl == null || adminUrl.isBlank()) {
			throw new IllegalStateException(
					"Model " + clean + " is not loaded. Set PASS_AI_INFERENCE_ADMIN_URL and switch on the GPU pod.");
		}
		WebClient client = adminClient(adminUrl);
		client.post()
				.uri("/v1/active")
				.contentType(MediaType.APPLICATION_JSON)
				.body(BodyInserters.fromValue(Map.of("modelId", clean)))
				.retrieve()
				.bodyToMono(String.class)
				.block();
		waitForInferenceReady();
	}

	public Map<String, Object> catalogResponse() {
		return Map.of(
				"activeModelId", activeModelId().orElse(properties.inference().defaultModel()),
				"models", catalog());
	}

	private void waitForInferenceReady() {
		for (int i = 0; i < 120; i++) {
			try {
				Thread.sleep(5000);
				Optional<String> active = activeModelId();
				if (active.isPresent() && proxyReachable()) {
					return;
				}
			}
			catch (InterruptedException ex) {
				Thread.currentThread().interrupt();
				return;
			}
		}
	}

	private boolean proxyReachable() {
		try {
			WebClient client = webClientBuilder.clone()
					.baseUrl(com.passconsulting.passai.config.WebClientConfig.normalizeBaseUrl(properties.inference().baseUrl()))
					.build();
			if (properties.inference().apiKey() != null && !properties.inference().apiKey().isBlank()) {
				client = client.mutate()
						.defaultHeader("Authorization", "Bearer " + properties.inference().apiKey())
						.build();
			}
			String body = client.get().uri("/models").retrieve().bodyToMono(String.class).block();
			return body != null && body.contains("data");
		}
		catch (Exception ex) {
			return false;
		}
	}

	private WebClient adminClient(String adminUrl) {
		String base = adminUrl.endsWith("/") ? adminUrl.substring(0, adminUrl.length() - 1) : adminUrl;
		WebClient.Builder builder = webClientBuilder.clone().baseUrl(base);
		String key = properties.inference().apiKey();
		if (key != null && !key.isBlank()) {
			builder.defaultHeader("Authorization", "Bearer " + key);
		}
		return builder.build();
	}

	private Optional<List<CatalogModel>> fetchRemoteCatalog() {
		String adminUrl = properties.inference().adminUrl();
		if (adminUrl == null || adminUrl.isBlank()) {
			return Optional.empty();
		}
		try {
			WebClient client = adminClient(adminUrl);
			String body = client.get().uri("/v1/catalog").retrieve().bodyToMono(String.class).block();
			if (body == null) {
				return Optional.empty();
			}
			JsonNode root = objectMapper.readTree(body);
			JsonNode models = root.path("models");
			if (!models.isArray()) {
				return Optional.empty();
			}
			List<CatalogModel> list = new java.util.ArrayList<>();
			for (JsonNode node : models) {
				list.add(catalogModelFromJson(node));
			}
			return Optional.of(list);
		}
		catch (Exception ex) {
			return Optional.empty();
		}
	}

	private List<CatalogModel> loadClasspathCatalog() {
		try (InputStream in = new ClassPathResource("pass-ai-models.catalog.json").getInputStream()) {
			JsonNode root = objectMapper.readTree(in);
			JsonNode models = root.path("models");
			List<CatalogModel> list = new java.util.ArrayList<>();
			for (JsonNode node : models) {
				list.add(catalogModelFromJson(node));
			}
			return list;
		}
		catch (IOException ex) {
			throw new IllegalStateException("Missing pass-ai-models.catalog.json", ex);
		}
	}

	public record CatalogModel(String id, String displayName, String description, String tier, int contextLength) {
	}

	private CatalogModel catalogModelFromJson(JsonNode node) {
		return new CatalogModel(
				node.path("id").asText(),
				node.path("displayName").asText(node.path("id").asText()),
				node.path("description").asText(""),
				node.path("tier").asText(""),
				node.path("contextLength").asInt(32768));
	}

	private static String escapeJson(String value) {
		return value.replace("\\", "\\\\").replace("\"", "\\\"");
	}
}
