package com.passconsulting.passai.inference;

import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

final class OpenAiToolCallResponseFixup {

	private OpenAiToolCallResponseFixup() {
	}

	static String maybeFix(String responseBody, ObjectMapper objectMapper) {
		try {
			JsonNode root = objectMapper.readTree(responseBody);
			JsonNode message = root.path("choices").path(0).path("message");
			if (!message.isObject()) {
				return responseBody;
			}
			if (message.has("tool_calls") && message.get("tool_calls").isArray()
					&& !message.get("tool_calls").isEmpty()) {
				return responseBody;
			}
			String content = message.path("content").asText("");
			List<LooseToolCallParser.ParsedToolCall> calls = LooseToolCallParser.parse(content, objectMapper);
			if (calls.isEmpty()) {
				return responseBody;
			}
			ObjectNode messageObj = (ObjectNode) message;
			messageObj.putNull("content");
			ArrayNode toolCalls = objectMapper.createArrayNode();
			for (LooseToolCallParser.ParsedToolCall call : calls) {
				ObjectNode tc = objectMapper.createObjectNode();
				tc.put("id", call.id());
				tc.put("type", "function");
				ObjectNode fn = objectMapper.createObjectNode();
				fn.put("name", call.name());
				fn.put("arguments", call.argumentsJson());
				tc.set("function", fn);
				toolCalls.add(tc);
			}
			messageObj.set("tool_calls", toolCalls);
			((ObjectNode) root.path("choices").path(0)).put("finish_reason", "tool_calls");
			return objectMapper.writeValueAsString(root);
		}
		catch (Exception ex) {
			return responseBody;
		}
	}
}
