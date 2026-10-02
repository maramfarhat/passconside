package com.passconsulting.passai.inference;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.servlet.http.HttpServletResponse;

@RestController
public class OpenAiProxyController {

	private final InferenceProxyService proxyService;
	private final ModelCatalogService catalogService;
	private final ObjectMapper objectMapper;

	public OpenAiProxyController(
			InferenceProxyService proxyService,
			ModelCatalogService catalogService,
			ObjectMapper objectMapper) {
		this.proxyService = proxyService;
		this.catalogService = catalogService;
		this.objectMapper = objectMapper;
	}

	@GetMapping("/v1/models")
	public ResponseEntity<String> models() {
		return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON)
				.body(catalogService.openAiModelsJson());
	}

	@PostMapping(value = "/v1/chat/completions", consumes = MediaType.APPLICATION_JSON_VALUE)
	public void chatCompletions(@RequestBody String requestBody, HttpServletResponse response) throws IOException {
		if (isStreamingRequest(requestBody)) {
			try {
				proxyService.prepareChatRequest(requestBody);
			}
			catch (ChatContextPreparer.ContextLimitExceededException ex) {
				writeJsonError(response, HttpServletResponse.SC_BAD_REQUEST, ex.getMessage());
				return;
			}
			response.setCharacterEncoding(StandardCharsets.UTF_8.name());
			response.setHeader("Cache-Control", "no-cache");
			response.setStatus(HttpServletResponse.SC_OK);
			response.setContentType(MediaType.TEXT_EVENT_STREAM_VALUE);
			var outputStream = response.getOutputStream();
			try {
				proxyService.writeChatCompletionsStream(requestBody, outputStream);
			}
			catch (ChatContextPreparer.ContextLimitExceededException ex) {
				writeStreamError(response, outputStream, ex.getMessage(), HttpServletResponse.SC_BAD_REQUEST);
			}
			catch (IOException ex) {
				writeStreamError(response, outputStream, ex.getMessage(), inferStreamErrorStatus(ex));
			}
			return;
		}

		try {
			ResponseEntity<String> result = proxyService.chatCompletions(requestBody);
			response.setStatus(result.getStatusCode().value());
			response.setContentType(MediaType.APPLICATION_JSON_VALUE);
			response.getWriter().write(result.getBody() != null ? result.getBody() : "");
		}
		catch (ChatContextPreparer.ContextLimitExceededException ex) {
			writeJsonError(response, HttpServletResponse.SC_BAD_REQUEST, ex.getMessage());
		}
	}

	private static void writeJsonError(HttpServletResponse response, int status, String message) throws IOException {
		response.setStatus(status);
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		String json = openAiErrorJson(message);
		response.getWriter().write(json);
	}

	private static void writeStreamError(
			HttpServletResponse response,
			java.io.OutputStream outputStream,
			String detail,
			int status) throws IOException {
		if (detail == null || detail.isBlank()) {
			detail = "Upstream inference failed";
		}
		if (!response.isCommitted()) {
			response.setStatus(status);
		}
		String payload = openAiErrorJson(detail);
		String sse = "data: " + payload + "\n\ndata: [DONE]\n\n";
		outputStream.write(sse.getBytes(StandardCharsets.UTF_8));
		outputStream.flush();
	}

	private static int inferStreamErrorStatus(IOException ex) {
		String lower = ex.getMessage() != null ? ex.getMessage().toLowerCase() : "";
		if (lower.contains("context") || lower.contains("too long") || lower.contains("maximum")
				|| lower.contains("400") || lower.contains("start a new task")) {
			return HttpServletResponse.SC_BAD_REQUEST;
		}
		return HttpServletResponse.SC_BAD_GATEWAY;
	}

	private static String openAiErrorJson(String message) {
		return "{\"error\":{\"message\":\"" + escapeJson(message) + "\",\"type\":\"context_length_exceeded\"}}";
	}

	private static String escapeJson(String value) {
		if (value == null) {
			return "";
		}
		return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ");
	}

	private boolean isStreamingRequest(String requestBody) {
		try {
			JsonNode root = objectMapper.readTree(requestBody);
			return root.path("stream").asBoolean(false);
		}
		catch (Exception ex) {
			return false;
		}
	}
}
