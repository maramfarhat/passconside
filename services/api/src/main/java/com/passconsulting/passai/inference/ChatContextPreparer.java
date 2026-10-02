package com.passconsulting.passai.inference;

import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.passconsulting.passai.config.PassAiProperties;

/**
 * Keeps chat requests within the active model context window by dropping oldest
 * non-system turns before they hit SGLang (which otherwise returns 400 mid-task).
 */
@Component
public class ChatContextPreparer {

	private static final int OUTPUT_RESERVE_TOKENS = 8192;
	private static final int SAFETY_MARGIN_TOKENS = 1024;

	private final ModelCatalogService catalogService;
	private final PassAiProperties properties;
	private final ObjectMapper objectMapper;

	public ChatContextPreparer(
			ModelCatalogService catalogService,
			PassAiProperties properties,
			ObjectMapper objectMapper) {
		this.catalogService = catalogService;
		this.properties = properties;
		this.objectMapper = objectMapper;
	}

	public PrepareResult prepare(String requestBody) throws ContextLimitExceededException {
		try {
			JsonNode root = objectMapper.readTree(requestBody);
			if (!root.isObject()) {
				return new PrepareResult(requestBody, false, 0);
			}
			ObjectNode obj = (ObjectNode) root;
			JsonNode messagesNode = obj.path("messages");
			if (!messagesNode.isArray() || messagesNode.isEmpty()) {
				return new PrepareResult(requestBody, false, 0);
			}

			String modelId = obj.path("model").asText(properties.inference().defaultModel());
			int contextLength = resolveContextLength(modelId);
			int maxTokens = obj.hasNonNull("max_tokens") ? obj.path("max_tokens").asInt() : OUTPUT_RESERVE_TOKENS;
			int outputReserve = Math.min(Math.max(maxTokens, 1024), contextLength / 4);
			int budget = Math.max(512, contextLength - outputReserve - SAFETY_MARGIN_TOKENS);

			ArrayNode messages = (ArrayNode) messagesNode;
			int estimated = estimateTokens(messages);
			if (estimated <= budget) {
				return new PrepareResult(requestBody, false, 0);
			}
			if (messages.size() == 1) {
				throw new ContextLimitExceededException(
						"This message is too large for the model context (~"
								+ contextLength
								+ " tokens). Start a new task or shorten the prompt.");
			}

			ArrayNode trimmed = trimMessages(messages, budget);
			int removed = messages.size() - trimmed.size();
			if (removed <= 0) {
				throw new ContextLimitExceededException(
						"This message is too large for the model context (~"
								+ contextLength
								+ " tokens). Start a new task or shorten the prompt.");
			}

			obj.set("messages", trimmed);
			String out = objectMapper.writeValueAsString(obj);
			return new PrepareResult(out, true, removed);
		}
		catch (ContextLimitExceededException ex) {
			throw ex;
		}
		catch (Exception ex) {
			return new PrepareResult(requestBody, false, 0);
		}
	}

	private int resolveContextLength(String modelId) {
		return catalogService.catalog().stream()
				.filter(m -> m.id().equals(modelId))
				.map(ModelCatalogService.CatalogModel::contextLength)
				.findFirst()
				.orElse(32768);
	}

	private static int estimateTokens(ArrayNode messages) {
		int chars = 0;
		for (JsonNode msg : messages) {
			chars += messageCharWeight(msg);
		}
		// Code-heavy agent chats skew high vs naive /4
		return (int) Math.ceil(chars / 3.0);
	}

	private static int messageCharWeight(JsonNode msg) {
		int chars = 0;
		JsonNode content = msg.path("content");
		if (content.isTextual()) {
			chars += content.asText("").length();
		}
		else if (content.isArray()) {
			for (JsonNode part : content) {
				if (part.path("type").asText("").equals("text")) {
					chars += part.path("text").asText("").length();
				}
			}
		}
		JsonNode toolCalls = msg.path("tool_calls");
		if (toolCalls.isArray()) {
			chars += toolCalls.toString().length();
		}
		JsonNode name = msg.path("name");
		if (name.isTextual()) {
			chars += name.asText("").length();
		}
		return chars + 24;
	}

	private static ArrayNode trimMessages(ArrayNode messages, int budget) {
		List<JsonNode> list = new ArrayList<>();
		messages.forEach(list::add);

		while (list.size() > 2 && estimateTokensFromList(list) > budget) {
			int removeAt = firstNonSystemIndex(list);
			if (removeAt < 0 || removeAt >= list.size() - 1) {
				break;
			}
			list.remove(removeAt);
			// Drop orphaned tool results after removing an assistant tool-call turn
			while (removeAt < list.size() && isToolRole(list.get(removeAt))) {
				list.remove(removeAt);
			}
		}

		ArrayNode out = messages.arrayNode();
		for (JsonNode node : list) {
			out.add(node);
		}
		return out;
	}

	private static int estimateTokensFromList(List<JsonNode> list) {
		int chars = 0;
		for (JsonNode msg : list) {
			chars += messageCharWeight(msg);
		}
		return (int) Math.ceil(chars / 3.0);
	}

	private static int firstNonSystemIndex(List<JsonNode> list) {
		for (int i = 0; i < list.size(); i++) {
			String role = list.get(i).path("role").asText("");
			if (!"system".equals(role)) {
				return i;
			}
		}
		return 0;
	}

	private static boolean isToolRole(JsonNode msg) {
		String role = msg.path("role").asText("");
		return "tool".equals(role) || "function".equals(role);
	}

	public record PrepareResult(String requestBody, boolean trimmed, int messagesRemoved) {
	}

	public static class ContextLimitExceededException extends Exception {

		public ContextLimitExceededException(String message) {
			super(message);
		}
	}
}
