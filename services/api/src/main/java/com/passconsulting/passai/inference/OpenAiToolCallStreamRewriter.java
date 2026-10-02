package com.passconsulting.passai.inference;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Buffers an upstream OpenAI SSE chat stream; if the assistant content contains loose tool JSON,
 * rewrites the stream into proper {@code tool_calls} chunks for Cline.
 */
final class OpenAiToolCallStreamRewriter {

	private final ObjectMapper objectMapper;

	OpenAiToolCallStreamRewriter(ObjectMapper objectMapper) {
		this.objectMapper = objectMapper;
	}

	void rewrite(InputStream upstream, OutputStream client) throws IOException {
		String raw = new String(upstream.readAllBytes(), StandardCharsets.UTF_8);
		List<String> events = splitSseEvents(raw);
		StringBuilder content = new StringBuilder();
		String firstRoleChunk = null;
		String model = null;
		String id = null;
		long created = 0;
		boolean upstreamHadToolCalls = false;

		for (String event : events) {
			if (event.isBlank() || event.startsWith(":")) {
				continue;
			}
			if (!event.startsWith("data: ")) {
				continue;
			}
			String payload = event.substring(6).trim();
			if ("[DONE]".equals(payload)) {
				continue;
			}
			JsonNode root = objectMapper.readTree(payload);
			if (model == null) {
				model = root.path("model").asText(null);
				id = root.path("id").asText(null);
				created = root.path("created").asLong(0);
			}
			JsonNode choices = root.path("choices");
			if (!choices.isArray() || choices.isEmpty()) {
				continue;
			}
			JsonNode choice = choices.get(0);
			JsonNode delta = choice.path("delta");
			if (delta.has("tool_calls") && delta.get("tool_calls").isArray() && !delta.get("tool_calls").isEmpty()) {
				upstreamHadToolCalls = true;
			}
			if (delta.has("content") && !delta.get("content").isNull()) {
				content.append(delta.get("content").asText(""));
			}
			if (firstRoleChunk == null && delta.has("role")) {
				firstRoleChunk = payload;
			}
		}

		List<LooseToolCallParser.ParsedToolCall> parsed = upstreamHadToolCalls
				? List.of()
				: LooseToolCallParser.parse(content.toString(), objectMapper);

		if (parsed.isEmpty()) {
			client.write(raw.getBytes(StandardCharsets.UTF_8));
			client.flush();
			return;
		}

		writeChunk(client, id, model, created, roleDelta());
		for (int i = 0; i < parsed.size(); i++) {
			LooseToolCallParser.ParsedToolCall call = parsed.get(i);
			writeToolCallStart(client, id, model, created, i, call.id(), call.name());
			writeToolCallArgs(client, id, model, created, i, call.argumentsJson());
		}
		writeFinish(client, id, model, created, "tool_calls");
		client.write("data: [DONE]\n\n".getBytes(StandardCharsets.UTF_8));
		client.flush();
	}

	private void writeChunk(OutputStream out, String id, String model, long created, ObjectNode delta)
			throws IOException {
		ObjectNode root = baseChunk(id, model, created);
		ArrayNode choices = objectMapper.createArrayNode();
		ObjectNode choice = objectMapper.createObjectNode();
		choice.put("index", 0);
		choice.set("delta", delta);
		choice.putNull("logprobs");
		choice.putNull("finish_reason");
		choices.add(choice);
		root.set("choices", choices);
		writeEvent(out, root);
	}

	private ObjectNode roleDelta() {
		ObjectNode delta = objectMapper.createObjectNode();
		delta.put("role", "assistant");
		delta.put("content", "");
		return delta;
	}

	private void writeToolCallStart(OutputStream out, String id, String model, long created, int index, String callId,
			String name) throws IOException {
		ObjectNode delta = objectMapper.createObjectNode();
		ArrayNode toolCalls = objectMapper.createArrayNode();
		ObjectNode tc = objectMapper.createObjectNode();
		tc.put("index", index);
		tc.put("id", callId);
		tc.put("type", "function");
		ObjectNode fn = objectMapper.createObjectNode();
		fn.put("name", name);
		fn.put("arguments", "");
		tc.set("function", fn);
		toolCalls.add(tc);
		delta.set("tool_calls", toolCalls);
		writeChunk(out, id, model, created, delta);
	}

	private void writeToolCallArgs(OutputStream out, String id, String model, long created, int index, String argsJson)
			throws IOException {
		ObjectNode delta = objectMapper.createObjectNode();
		ArrayNode toolCalls = objectMapper.createArrayNode();
		ObjectNode tc = objectMapper.createObjectNode();
		tc.put("index", index);
		ObjectNode fn = objectMapper.createObjectNode();
		fn.put("arguments", argsJson);
		tc.set("function", fn);
		toolCalls.add(tc);
		delta.set("tool_calls", toolCalls);
		writeChunk(out, id, model, created, delta);
	}

	private void writeFinish(OutputStream out, String id, String model, long created, String reason)
			throws IOException {
		ObjectNode root = baseChunk(id, model, created);
		ArrayNode choices = objectMapper.createArrayNode();
		ObjectNode choice = objectMapper.createObjectNode();
		choice.put("index", 0);
		choice.set("delta", objectMapper.createObjectNode());
		choice.putNull("logprobs");
		choice.put("finish_reason", reason);
		choices.add(choice);
		root.set("choices", choices);
		writeEvent(out, root);
	}

	private ObjectNode baseChunk(String id, String model, long created) {
		ObjectNode root = objectMapper.createObjectNode();
		if (id != null) {
			root.put("id", id);
		}
		root.put("object", "chat.completion.chunk");
		if (created > 0) {
			root.put("created", created);
		}
		if (model != null) {
			root.put("model", model);
		}
		return root;
	}

	private void writeEvent(OutputStream out, JsonNode root) throws IOException {
		out.write(("data: " + objectMapper.writeValueAsString(root) + "\n\n").getBytes(StandardCharsets.UTF_8));
	}

	private static List<String> splitSseEvents(String raw) {
		List<String> events = new ArrayList<>();
		for (String part : raw.split("\n\n")) {
			events.add(part.trim());
		}
		return events;
	}
}
