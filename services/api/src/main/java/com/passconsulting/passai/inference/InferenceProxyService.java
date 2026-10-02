package com.passconsulting.passai.inference;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;

import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.passconsulting.passai.config.PassAiProperties;

import reactor.core.publisher.Mono;

@Service
public class InferenceProxyService {

	private final WebClient inferenceWebClient;
	private final PassAiProperties properties;
	private final ModelCatalogService catalogService;
	private final ObjectMapper objectMapper;
	private final ChatContextPreparer contextPreparer;

	public InferenceProxyService(
			WebClient inferenceWebClient,
			PassAiProperties properties,
			ModelCatalogService catalogService,
			ObjectMapper objectMapper,
			ChatContextPreparer contextPreparer) {
		this.inferenceWebClient = inferenceWebClient;
		this.properties = properties;
		this.catalogService = catalogService;
		this.objectMapper = objectMapper;
		this.contextPreparer = contextPreparer;
	}

	/** Validates / trims before opening an SSE stream (fail fast with JSON, not 500). */
	public void prepareChatRequest(String requestBody) throws ChatContextPreparer.ContextLimitExceededException {
		contextPreparer.prepare(requestBody);
	}

	public ResponseEntity<String> listModels() {
		try {
			String body = inferenceWebClient.get()
					.uri("/models")
					.retrieve()
					.bodyToMono(String.class)
					.block();
			return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(body);
		}
		catch (WebClientResponseException ex) {
			return ResponseEntity.status(ex.getStatusCode())
					.contentType(MediaType.APPLICATION_JSON)
					.body(ex.getResponseBodyAsString());
		}
	}

	public ResponseEntity<String> chatCompletions(String requestBody) throws ChatContextPreparer.ContextLimitExceededException {
		ChatContextPreparer.PrepareResult prepared = contextPreparer.prepare(requestBody);
		requestBody = prepared.requestBody();
		prepareModel(requestBody);
		try {
			String body = inferenceWebClient.post()
					.uri("/chat/completions")
					.contentType(MediaType.APPLICATION_JSON)
					.body(BodyInserters.fromValue(requestBody))
					.retrieve()
					.bodyToMono(String.class)
					.block();
			if (requestIncludesTools(requestBody) && needsLooseToolStreamRewrite(requestBody) && body != null) {
				body = OpenAiToolCallResponseFixup.maybeFix(body, objectMapper);
			}
			return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(body);
		}
		catch (WebClientResponseException ex) {
			return ResponseEntity.status(ex.getStatusCode())
					.contentType(MediaType.APPLICATION_JSON)
					.body(ex.getResponseBodyAsString());
		}
	}

	public void writeChatCompletionsStream(String requestBody, OutputStream outputStream)
			throws IOException, ChatContextPreparer.ContextLimitExceededException {
		ChatContextPreparer.PrepareResult prepared = contextPreparer.prepare(requestBody);
		requestBody = prepared.requestBody();
		prepareModel(requestBody);
		try {
			var flux = inferenceWebClient.post()
					.uri("/chat/completions")
					.contentType(MediaType.APPLICATION_JSON)
					.accept(MediaType.TEXT_EVENT_STREAM)
					.body(BodyInserters.fromValue(requestBody))
					.exchangeToFlux(response -> {
						if (response.statusCode().isError()) {
							return response.bodyToMono(String.class)
									.flatMapMany(err -> Mono.error(new WebClientResponseException(
											response.statusCode().value(),
											response.statusCode().toString(),
											response.headers().asHttpHeaders(),
											err.getBytes(),
											null)));
						}
						return response.bodyToFlux(org.springframework.core.io.buffer.DataBuffer.class);
					});
			if (requestIncludesTools(requestBody) && needsLooseToolStreamRewrite(requestBody)) {
				ByteArrayOutputStream buffer = new ByteArrayOutputStream();
				DataBufferUtils.write(flux, buffer).blockLast();
				new OpenAiToolCallStreamRewriter(objectMapper)
						.rewrite(new ByteArrayInputStream(buffer.toByteArray()), outputStream);
			}
			else {
				DataBufferUtils.write(flux, outputStream).blockLast();
				outputStream.flush();
			}
		}
		catch (WebClientResponseException ex) {
			throw new IOException(friendlyUpstreamMessage(ex), ex);
		}
	}

	private static String friendlyUpstreamMessage(WebClientResponseException ex) {
		String body = ex.getResponseBodyAsString();
		if (body != null && !body.isBlank()) {
			return body;
		}
		if (ex.getStatusCode().value() == 400) {
			return "GPU rejected the request (context likely full). Start a new task or let PASS AI trim history on the next turn.";
		}
		return ex.getMessage() != null ? ex.getMessage() : "Upstream inference failed";
	}

	public InferenceStatus status() {
		try {
			String models = inferenceWebClient.get()
					.uri("/models")
					.retrieve()
					.bodyToMono(String.class)
					.block();
			return new InferenceStatus(true, properties.inference().baseUrl(), properties.inference().defaultModel(),
					models != null && models.length() > 2);
		}
		catch (Exception ex) {
			return new InferenceStatus(false, properties.inference().baseUrl(), properties.inference().defaultModel(),
					false);
		}
	}

	public record InferenceStatus(boolean reachable, String upstreamBaseUrl, String defaultModel, boolean modelsListed) {
	}

	private boolean requestIncludesTools(String requestBody) {
		try {
			JsonNode root = objectMapper.readTree(requestBody);
			JsonNode tools = root.path("tools");
			return tools.isArray() && !tools.isEmpty();
		}
		catch (Exception ex) {
			return false;
		}
	}

	/** Qwen3 Coder models emit native tool_calls; only Qwen2.5 needs text→tool rewrite. */
	private boolean needsLooseToolStreamRewrite(String requestBody) {
		try {
			String model = objectMapper.readTree(requestBody).path("model").asText("").toLowerCase();
			return model.contains("qwen2.5") || model.contains("2.5-coder");
		}
		catch (Exception ex) {
			return true;
		}
	}

	private void prepareModel(String requestBody) {
		try {
			JsonNode root = objectMapper.readTree(requestBody);
			String model = root.path("model").asText(null);
			if (model != null) {
				catalogService.ensureActiveModel(model);
			}
		}
		catch (IllegalStateException ex) {
			throw ex;
		}
		catch (Exception ex) {
			// ignore malformed bodies; upstream will reject
		}
	}
}
