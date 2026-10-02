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
			response.setStatus(HttpServletResponse.SC_OK);
			response.setContentType(MediaType.TEXT_EVENT_STREAM_VALUE);
			response.setCharacterEncoding(StandardCharsets.UTF_8.name());
			response.setHeader("Cache-Control", "no-cache");
			try {
				proxyService.writeChatCompletionsStream(requestBody, response.getOutputStream());
			}
			catch (IOException ex) {
				if (!response.isCommitted()) {
					response.resetBuffer();
					response.setStatus(HttpServletResponse.SC_BAD_GATEWAY);
					response.setContentType(MediaType.APPLICATION_JSON_VALUE);
					response.getWriter().write("{\"error\":{\"message\":\"" + escapeJson(ex.getMessage()) + "\"}}");
				}
			}
			return;
		}

		ResponseEntity<String> result = proxyService.chatCompletions(requestBody);
		response.setStatus(result.getStatusCode().value());
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		response.getWriter().write(result.getBody() != null ? result.getBody() : "");
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
